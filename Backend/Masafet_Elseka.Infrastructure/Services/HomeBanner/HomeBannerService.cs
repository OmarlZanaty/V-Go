using Masafet_Elseka.Application.ExternalInterfaces.ICloudinaryService;
using Masafet_Elseka.Application.Interfaces.HomeBanner;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.HomeBanner
{
    public class HomeBannerService : IHomeBannerService
    {
        private readonly Context _context;
        private readonly ICloudinaryService _cloudinaryService;

        public HomeBannerService(Context context, ICloudinaryService cloudinaryService)
        {
            _context = context;
            _cloudinaryService = cloudinaryService;
        }

        public async Task<Response<List<string>>> GetHomeBannersAsync()
        {
            try
            {
                var banners = _context.HomeBanners.OrderBy(b => b.Position)
                    .Take(4).Select(b => b.ImageUrl).ToList();
                if (banners == null || banners.Count == 0)
                {
                    return Response<List<string>>.Success(new List<string>(), "لا يوجد صور", 200);
                }
                return Response<List<string>>.Success(banners, "تم جلب الصور بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<List<string>>.Failure($"حدث خطأ أثناء جلب الصور: {ex.Message}", 500);
            }
        }

        public async Task<Response<string>> AddBannersAsync(List<IFormFile> banners)
        {
            try
            {
                if (!banners.Any() || banners.Count == 0)
                {
                    return Response<string>.Failure("يجب اختيار صور لتحميلها", 400);
                }

                var existingBannersCount = _context.HomeBanners.Count();
                if (existingBannersCount + banners.Count > 4)
                {
                    return Response<string>.Failure("لا يمكن إضافة أكثر من 4 صور في البانر الرئيسي", 400);
                }

                foreach (var banner in banners)
                {
                    var uploadResult = await _cloudinaryService.UploadFileAsync(banner);
                    var url = uploadResult.Url;
                    var homeBanner = new Domain.Entities.HomeBanner
                    {
                        ImageUrl = url,
                        Position = _context.HomeBanners.Count() + 1
                    };

                    _context.HomeBanners.Add(homeBanner);
                }
                await _context.SaveChangesAsync();
                return Response<string>.Success("تم إضافة الصور بنجاح", "تم إضافة الصور بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<string>.Failure($"حدث خطأ أثناء إضافة الصور: {ex.Message}", 500);
            }
        }

        public async Task<Response<string>> RemoveBannersAsync(List<string> bannersUrls)
        {
            try
            {
                var existingBannersCount = _context.HomeBanners.Count();
                if (existingBannersCount <= 1)
                {
                    return Response<string>.Failure("يجب أن يكون هناك على الأقل صورة واحدة في البانر الرئيسي", 400);
                }

                foreach (var url in bannersUrls)
                {
                    var banner = _context.HomeBanners.FirstOrDefault(b => b.ImageUrl == url);
                    if (banner != null)
                    {
                        _context.HomeBanners.Remove(banner);
                    }
                }

                await _context.SaveChangesAsync();
                return Response<string>.Success("تم حذف الصور المحددة بنجاح", "تم حذف الصور المحددة بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<string>.Failure($"حدث خطأ أثناء حذف الصور: {ex.Message}", 500);
            }
        }
    }
}
