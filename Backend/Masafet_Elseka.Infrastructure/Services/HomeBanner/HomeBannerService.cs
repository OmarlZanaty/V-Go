using Masafet_Elseka.Application.DTOs.HomeBanner;
using Masafet_Elseka.Application.Interfaces.HomeBanner;
using Masafet_Elseka.Application.Interfaces.IDriverFinanceService;
using Masafet_Elseka.Application.Interfaces.IPrivateFileStorage;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace Masafet_Elseka.Infrastructure.Services.HomeBanner
{
    // Ad slots in the rider app's home carousel. Images live on the server's public
    // /media volume; the dashboard controls image, link, order, visibility and dates.
    public class HomeBannerService : IHomeBannerService
    {
        public const int MaxBanners = 10;
        private const long MaxImageBytes = 5 * 1024 * 1024;

        private readonly Context _context;
        private readonly IPublicMediaStorage _media;
        private readonly IDriverFinanceService _audit;

        public HomeBannerService(Context context, IPublicMediaStorage media, IDriverFinanceService audit)
        {
            _context = context;
            _media = media;
            _audit = audit;
        }

        private static DateTime Now => DateTime.Now.ToEgyptTime();

        private static bool IsLive(Domain.Entities.HomeBanner b, DateTime now) =>
            b.IsActive && (b.StartsAt == null || b.StartsAt <= now) && (b.EndsAt == null || b.EndsAt > now);

        private static AdminBannerDTO ToDto(Domain.Entities.HomeBanner b, DateTime now) => new()
        {
            Id = b.Id,
            ImageUrl = b.ImageUrl,
            Position = b.Position,
            Title = b.Title,
            LinkUrl = b.LinkUrl,
            IsActive = b.IsActive,
            StartsAt = b.StartsAt,
            EndsAt = b.EndsAt,
            IsLive = IsLive(b, now),
            ClickCount = b.ClickCount,
            CreatedAt = b.CreatedAt,
            UpdatedAt = b.UpdatedAt,
        };

        public async Task<Response<List<ActiveBannerDTO>>> GetActiveAsync()
        {
            var now = Now;
            var banners = await _context.HomeBanners.AsNoTracking()
                .Where(b => b.IsActive && (b.StartsAt == null || b.StartsAt <= now) && (b.EndsAt == null || b.EndsAt > now))
                .OrderBy(b => b.Position).ThenBy(b => b.Id)
                .Select(b => new ActiveBannerDTO { Id = b.Id, ImageUrl = b.ImageUrl, LinkUrl = b.LinkUrl })
                .ToListAsync();
            return Response<List<ActiveBannerDTO>>.Success(banners, "", 200);
        }

        public async Task RecordClickAsync(int id)
        {
            try
            {
                await _context.HomeBanners.Where(b => b.Id == id)
                    .ExecuteUpdateAsync(s => s.SetProperty(b => b.ClickCount, b => b.ClickCount + 1));
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Banner click count failed for {BannerId}", id);
            }
        }

        public async Task<Response<List<AdminBannerDTO>>> GetAllAsync()
        {
            var now = Now;
            var banners = await _context.HomeBanners.AsNoTracking()
                .OrderBy(b => b.Position).ThenBy(b => b.Id).ToListAsync();
            return Response<List<AdminBannerDTO>>.Success(banners.Select(b => ToDto(b, now)).ToList(), "", 200);
        }

        // Returns an Arabic error, or null when the fields are valid. Normalises the link.
        private static string? Validate(SaveBannerDTO dto)
        {
            if (!string.IsNullOrWhiteSpace(dto.LinkUrl))
            {
                var link = dto.LinkUrl.Trim();
                if (!link.Contains("://")) link = "https://" + link;
                if (!Uri.TryCreate(link, UriKind.Absolute, out var uri)
                    || (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps)
                    || string.IsNullOrEmpty(uri.Host) || !uri.Host.Contains('.'))
                    return "الرابط غير صالح، اكتب رابط موقع كامل مثل https://example.com";
                dto.LinkUrl = uri.ToString();
            }
            else
            {
                dto.LinkUrl = null;
            }

            dto.Title = string.IsNullOrWhiteSpace(dto.Title) ? null : dto.Title.Trim();
            if (dto.Title?.Length > 100) return "اسم الإعلان طويل جداً (الحد 100 حرف)";
            if (dto.StartsAt != null && dto.EndsAt != null && dto.EndsAt <= dto.StartsAt)
                return "تاريخ نهاية الإعلان لازم يكون بعد تاريخ البداية";
            return null;
        }

        // Sniffs the real format; returns (extension) or an Arabic error.
        private static async Task<(string? Ext, string? Error)> CheckImageAsync(IFormFile? image)
        {
            if (image == null || image.Length == 0) return (null, "اختار صورة الإعلان");
            if (image.Length > MaxImageBytes) return (null, "حجم الصورة كبير، الحد الأقصى 5 ميجا");
            var head = new byte[12];
            await using (var s = image.OpenReadStream())
            {
                var read = await s.ReadAsync(head.AsMemory(0, head.Length));
                if (read < head.Length) Array.Resize(ref head, read);
            }
            if (head.Length >= 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF) return (".jpg", null);
            if (head.Length >= 8 && head[0] == 0x89 && head[1] == 0x50 && head[2] == 0x4E && head[3] == 0x47) return (".png", null);
            if (head.Length >= 12 && head[0] == 'R' && head[1] == 'I' && head[2] == 'F' && head[3] == 'F'
                && head[8] == 'W' && head[9] == 'E' && head[10] == 'B' && head[11] == 'P') return (".webp", null);
            return (null, "الصورة لازم تكون JPG أو PNG أو WEBP");
        }

        private async Task<string> SaveImageAsync(IFormFile image, string ext)
        {
            await using var stream = image.OpenReadStream();
            return await _media.SaveAsync(stream, "banners", ext);
        }

        public async Task<Response<AdminBannerDTO>> CreateAsync(SaveBannerDTO dto, IFormFile? image, string actorUserId)
        {
            if (await _context.HomeBanners.CountAsync() >= MaxBanners)
                return Response<AdminBannerDTO>.Failure($"الحد الأقصى {MaxBanners} إعلانات، احذف إعلان قديم الأول", 400);
            var error = Validate(dto);
            if (error != null) return Response<AdminBannerDTO>.Failure(error, 400);
            var (ext, imageError) = await CheckImageAsync(image);
            if (imageError != null) return Response<AdminBannerDTO>.Failure(imageError, 400);

            var now = Now;
            var banner = new Domain.Entities.HomeBanner
            {
                ImageUrl = await SaveImageAsync(image!, ext!),
                Position = (await _context.HomeBanners.MaxAsync(b => (int?)b.Position) ?? 0) + 1,
                Title = dto.Title,
                LinkUrl = dto.LinkUrl,
                IsActive = dto.IsActive,
                StartsAt = dto.StartsAt,
                EndsAt = dto.EndsAt,
                CreatedAt = now,
            };
            _context.HomeBanners.Add(banner);
            await _context.SaveChangesAsync();
            await _audit.WriteAuditAsync(actorUserId, "BannerCreated", null, $"#{banner.Id} {banner.Title} {banner.LinkUrl}");
            return Response<AdminBannerDTO>.Success(ToDto(banner, now), "تمت إضافة الإعلان", 201);
        }

        public async Task<Response<AdminBannerDTO>> UpdateAsync(int id, SaveBannerDTO dto, IFormFile? image, string actorUserId)
        {
            var banner = await _context.HomeBanners.FirstOrDefaultAsync(b => b.Id == id);
            if (banner == null) return Response<AdminBannerDTO>.Failure("الإعلان غير موجود", 404);
            var error = Validate(dto);
            if (error != null) return Response<AdminBannerDTO>.Failure(error, 400);

            string? oldImage = null;
            if (image != null && image.Length > 0)
            {
                var (ext, imageError) = await CheckImageAsync(image);
                if (imageError != null) return Response<AdminBannerDTO>.Failure(imageError, 400);
                oldImage = banner.ImageUrl;
                banner.ImageUrl = await SaveImageAsync(image, ext!);
            }

            banner.Title = dto.Title;
            banner.LinkUrl = dto.LinkUrl;
            banner.IsActive = dto.IsActive;
            banner.StartsAt = dto.StartsAt;
            banner.EndsAt = dto.EndsAt;
            banner.UpdatedAt = Now;
            await _context.SaveChangesAsync();
            if (oldImage != null) _media.Delete(oldImage);

            await _audit.WriteAuditAsync(actorUserId, "BannerUpdated", null,
                $"#{banner.Id} {banner.Title} active={banner.IsActive} link={banner.LinkUrl}" + (oldImage != null ? " (new image)" : ""));
            return Response<AdminBannerDTO>.Success(ToDto(banner, Now), "تم حفظ الإعلان", 200);
        }

        public async Task<Response<string>> DeleteAsync(int id, string actorUserId)
        {
            var banner = await _context.HomeBanners.FirstOrDefaultAsync(b => b.Id == id);
            if (banner == null) return Response<string>.Failure("الإعلان غير موجود", 404);
            _context.HomeBanners.Remove(banner);
            await _context.SaveChangesAsync();
            _media.Delete(banner.ImageUrl);
            await _audit.WriteAuditAsync(actorUserId, "BannerDeleted", null, $"#{banner.Id} {banner.Title}");
            return Response<string>.Success("ok", "تم حذف الإعلان", 200);
        }

        public async Task<Response<List<AdminBannerDTO>>> ReorderAsync(List<int> orderedIds, string actorUserId)
        {
            var banners = await _context.HomeBanners.ToListAsync();
            if (orderedIds == null || orderedIds.Count != banners.Count || orderedIds.Distinct().Count() != banners.Count
                || !banners.All(b => orderedIds.Contains(b.Id)))
                return Response<List<AdminBannerDTO>>.Failure("ترتيب غير صالح، حدّث الصفحة وحاول تاني", 400);

            for (var i = 0; i < orderedIds.Count; i++)
                banners.First(b => b.Id == orderedIds[i]).Position = i + 1;
            await _context.SaveChangesAsync();
            await _audit.WriteAuditAsync(actorUserId, "BannersReordered", null, string.Join(",", orderedIds));
            return await GetAllAsync();
        }
    }
}
