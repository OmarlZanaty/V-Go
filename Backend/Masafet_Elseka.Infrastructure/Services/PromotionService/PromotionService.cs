using System.Data;
using System.Text.RegularExpressions;
using Masafet_Elseka.Application.DTOs.FreeRides;
using Masafet_Elseka.Application.DTOs.Promotions;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Application.Interfaces.IPromotionService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Masafet_Elseka.Infrastructure.Services.PromotionService
{
    public class PromotionService : IPromotionService
    {
        private static readonly Regex CodePattern = new("^[A-Z0-9_-]{3,32}$", RegexOptions.Compiled);

        private readonly Context _context;

        public PromotionService(Context context)
        {
            _context = context;
        }

        private static DateTime Now => DateTime.Now.ToEgyptTime();

        private IQueryable<Promotion> Running(DateTime now) => _context.Promotions
            .Where(p => p.IsActive &&
                (p.StartsAt == null || p.StartsAt <= now) &&
                (p.EndsAt == null || p.EndsAt >= now));

        // Grants are counted against the rider limit, so joining an offer is
        // serialized (sign-up, code entry and trip creation all take this lock).
        private async Task AcquireLockAsync()
        {
            await _context.Database.ExecuteSqlRawAsync(
                "DECLARE @r int; EXEC @r = sp_getapplock @Resource = {0}, @LockMode = 'Exclusive', " +
                "@LockOwner = 'Transaction', @LockTimeout = 15000; " +
                "IF @r < 0 THROW 51001, 'promotions lock timeout', 1;",
                "promotions");
        }

        private async Task InTransactionAsync(Func<Task> work)
        {
            if (_context.Database.CurrentTransaction != null)
            {
                await work();
                return;
            }
            await using var tx = await _context.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            await work();
            await tx.CommitAsync();
        }

        // What an offer takes off a fare, in whole pounds, never more than the fare.
        public static decimal DiscountFor(Promotion p, decimal fare)
        {
            if (fare <= 0) return 0m;
            var discount = p.Type switch
            {
                PromotionType.FreeRide => fare,
                PromotionType.PercentOff => Math.Round(fare * p.Value / 100, 0, MidpointRounding.AwayFromZero),
                PromotionType.AmountOff => Math.Round(p.Value, 0, MidpointRounding.AwayFromZero),
                _ => 0m
            };
            if (p.Type == PromotionType.PercentOff && p.MaxDiscount is > 0)
                discount = Math.Min(discount, p.MaxDiscount.Value);
            return Math.Clamp(discount, 0m, fare);
        }

        private sealed record Candidate(Promotion Promotion, bool HasGrant, int Used);

        // Running offers this rider can use now, with how many rides they used.
        private async Task<List<Candidate>> CandidatesAsync(string userId, DateTime now)
        {
            var running = await Running(now).AsNoTracking().ToListAsync();
            if (running.Count == 0) return new();

            var ids = running.Select(p => p.Id).ToList();
            var granted = await _context.PromotionGrants
                .Where(g => g.UserId == userId && ids.Contains(g.PromotionId))
                .Select(g => g.PromotionId)
                .ToListAsync();
            var used = await _context.Trips
                .Where(t => t.PromotionId != null && ids.Contains(t.PromotionId.Value) &&
                    t.Status != TripStatus.Canceled && t.Status != TripStatus.Rejected &&
                    t.UserTrips.Any(ut => ut.UserId == userId && ut.Role == UserTripRole.Client))
                .GroupBy(t => t.PromotionId!.Value)
                .Select(g => new { Id = g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.Id, x => x.Count);

            // All-riders offers are open until their rider limit is reached.
            var openAll = running.Where(p => p.Audience == PromotionAudience.AllRiders && !granted.Contains(p.Id)).ToList();
            var fullAll = new HashSet<int>();
            foreach (var p in openAll.Where(p => p.RiderLimit != null))
            {
                var count = await _context.PromotionGrants.CountAsync(g => g.PromotionId == p.Id);
                if (count >= p.RiderLimit) fullAll.Add(p.Id);
            }

            var result = new List<Candidate>();
            foreach (var p in running)
            {
                var hasGrant = granted.Contains(p.Id);
                if (!hasGrant && (p.Audience != PromotionAudience.AllRiders || fullAll.Contains(p.Id)))
                    continue;
                var u = used.GetValueOrDefault(p.Id);
                if (u >= p.RidesPerRider) continue;
                result.Add(new Candidate(p, hasGrant, u));
            }
            return result;
        }

        private static (Candidate c, decimal discount)? Best(List<Candidate> candidates, decimal fare)
        {
            return candidates
                .Select(c => (c, discount: DiscountFor(c.Promotion, fare)))
                .Where(x => x.discount > 0)
                .OrderByDescending(x => x.discount)
                .ThenBy(x => x.c.Promotion.EndsAt ?? DateTime.MaxValue)
                .ThenBy(x => x.c.Promotion.Id)
                .Select(x => ((Candidate, decimal)?)x)
                .FirstOrDefault();
        }

        private static PromotionQuote ToQuote(Candidate c, decimal discount) => new()
        {
            PromotionId = c.Promotion.Id,
            Title = c.Promotion.Title,
            Type = c.Promotion.Type,
            Discount = discount,
            RidesLeft = c.Promotion.RidesPerRider - c.Used,
        };

        public async Task<PromotionQuote?> BestOfferAsync(string? userId, decimal fare)
        {
            if (string.IsNullOrWhiteSpace(userId)) return null;
            var best = Best(await CandidatesAsync(userId, Now), fare);
            return best == null ? null : ToQuote(best.Value.c, best.Value.discount);
        }

        public async Task<PromotionQuote?> ApplyToNewTripAsync(string userId, decimal fare)
        {
            if (string.IsNullOrWhiteSpace(userId)) return null;
            PromotionQuote? quote = null;
            await InTransactionAsync(async () =>
            {
                await AcquireLockAsync();
                var best = Best(await CandidatesAsync(userId, Now), fare);
                if (best == null) return;
                var (c, discount) = best.Value;
                if (!c.HasGrant)
                {
                    _context.PromotionGrants.Add(new PromotionGrant
                    {
                        PromotionId = c.Promotion.Id,
                        UserId = userId,
                        GrantedAt = Now,
                    });
                    await _context.SaveChangesAsync();
                }
                quote = ToQuote(c, discount);
            });
            return quote;
        }

        public async Task GrantSignUpOffersAsync(ApplicationUser user)
        {
            if (user == null || string.IsNullOrWhiteSpace(user.Id)) return;
            await InTransactionAsync(async () =>
            {
                await AcquireLockAsync();
                var offers = await Running(Now)
                    .Where(p => p.Audience == PromotionAudience.NewRiders)
                    .Select(p => new
                    {
                        p.Id,
                        p.RiderLimit,
                        Granted = p.Grants.Count(),
                        Mine = p.Grants.Any(g => g.UserId == user.Id)
                    })
                    .ToListAsync();
                var added = false;
                foreach (var o in offers)
                {
                    if (o.Mine || (o.RiderLimit != null && o.Granted >= o.RiderLimit)) continue;
                    _context.PromotionGrants.Add(new PromotionGrant { PromotionId = o.Id, UserId = user.Id, GrantedAt = Now });
                    added = true;
                }
                if (added) await _context.SaveChangesAsync();
            });
        }

        public async Task<List<MyPromotionDTO>> GetMineAsync(string userId)
        {
            if (string.IsNullOrWhiteSpace(userId)) return new();
            var candidates = await CandidatesAsync(userId, Now);
            return candidates
                .OrderBy(c => c.Promotion.EndsAt ?? DateTime.MaxValue)
                .ThenBy(c => c.Promotion.Id)
                .Select(c => ToMine(c.Promotion, c.Used))
                .ToList();
        }

        private static MyPromotionDTO ToMine(Promotion p, int used) => new()
        {
            Id = p.Id,
            Title = p.Title,
            Description = p.Description,
            Type = p.Type,
            Value = p.Value,
            MaxDiscount = p.MaxDiscount,
            RidesPerRider = p.RidesPerRider,
            RidesUsed = used,
            RidesLeft = Math.Max(0, p.RidesPerRider - used),
            EndsAt = p.EndsAt,
            Code = p.Code,
        };

        public async Task<Response<MyPromotionDTO>> RedeemCodeAsync(string userId, string code)
        {
            var normalized = (code ?? "").Trim().ToUpperInvariant();
            if (string.IsNullOrEmpty(normalized))
                return Response<MyPromotionDTO>.Failure("اكتب كود العرض", 400);

            Response<MyPromotionDTO>? result = null;
            await InTransactionAsync(async () =>
            {
                await AcquireLockAsync();
                var now = Now;
                var promo = await _context.Promotions
                    .FirstOrDefaultAsync(p => p.Code == normalized && p.Audience == PromotionAudience.PromoCode);
                if (promo == null)
                {
                    result = Response<MyPromotionDTO>.Failure("الكود غير صحيح", 404);
                    return;
                }
                if (!promo.IsActive || (promo.StartsAt != null && promo.StartsAt > now))
                {
                    result = Response<MyPromotionDTO>.Failure("هذا العرض غير متاح حالياً", 400);
                    return;
                }
                if (promo.EndsAt != null && promo.EndsAt < now)
                {
                    result = Response<MyPromotionDTO>.Failure("انتهى هذا العرض", 400);
                    return;
                }

                var used = await _context.Trips.CountAsync(t => t.PromotionId == promo.Id &&
                    t.Status != TripStatus.Canceled && t.Status != TripStatus.Rejected &&
                    t.UserTrips.Any(ut => ut.UserId == userId && ut.Role == UserTripRole.Client));
                if (await _context.PromotionGrants.AnyAsync(g => g.PromotionId == promo.Id && g.UserId == userId))
                {
                    result = used >= promo.RidesPerRider
                        ? Response<MyPromotionDTO>.Failure("استخدمت هذا العرض بالكامل", 400)
                        : Response<MyPromotionDTO>.Success(ToMine(promo, used), "العرض مفعّل على حسابك بالفعل", 200);
                    return;
                }
                if (promo.RiderLimit != null &&
                    await _context.PromotionGrants.CountAsync(g => g.PromotionId == promo.Id) >= promo.RiderLimit)
                {
                    result = Response<MyPromotionDTO>.Failure("وصل هذا العرض للحد الأقصى من المستخدمين", 400);
                    return;
                }

                _context.PromotionGrants.Add(new PromotionGrant { PromotionId = promo.Id, UserId = userId, GrantedAt = now });
                await _context.SaveChangesAsync();
                result = Response<MyPromotionDTO>.Success(ToMine(promo, used), "تم تفعيل العرض على حسابك", 200);
            });
            return result!;
        }

        public async Task<FreeRidesStatusDTO> GetFreeRidesStatusAsync(string userId)
        {
            var now = Now;
            var enabled = await Running(now).AnyAsync(p => p.Type == PromotionType.FreeRide);
            if (string.IsNullOrWhiteSpace(userId))
                return new FreeRidesStatusDTO { Enabled = enabled };

            var free = (await CandidatesAsync(userId, now))
                .Where(c => c.Promotion.Type == PromotionType.FreeRide)
                .ToList();
            var used = await _context.Trips.CountAsync(t => t.IsFreeRide &&
                t.Status != TripStatus.Canceled && t.Status != TripStatus.Rejected &&
                t.UserTrips.Any(ut => ut.UserId == userId && ut.Role == UserTripRole.Client));
            var remaining = free.Sum(c => c.Promotion.RidesPerRider - c.Used);
            return new FreeRidesStatusDTO
            {
                Enabled = enabled,
                Granted = used + remaining,
                Used = used,
                Remaining = remaining,
            };
        }

        // ---- Dashboard -------------------------------------------------------

        public async Task<List<PromotionAdminDTO>> GetAllAsync()
        {
            var now = Now;
            var promos = await _context.Promotions.AsNoTracking()
                .OrderByDescending(p => p.CreatedAt)
                .Select(p => new
                {
                    Promotion = p,
                    GrantedRiders = p.Grants.Count(),
                })
                .ToListAsync();
            var stats = await _context.Trips
                .Where(t => t.PromotionId != null && t.Status != TripStatus.Canceled && t.Status != TripStatus.Rejected)
                .GroupBy(t => t.PromotionId!.Value)
                .Select(g => new
                {
                    Id = g.Key,
                    Used = g.Count(),
                    Completed = g.Count(t => t.Status == TripStatus.Completed),
                    Cost = g.Where(t => t.Status == TripStatus.Completed).Sum(t => (decimal?)t.DiscountAmount) ?? 0m,
                })
                .ToDictionaryAsync(x => x.Id);

            return promos.Select(x =>
            {
                stats.TryGetValue(x.Promotion.Id, out var s);
                return ToAdmin(x.Promotion, now, x.GrantedRiders, s?.Used ?? 0, s?.Completed ?? 0, s?.Cost ?? 0m);
            }).ToList();
        }

        private static PromotionAdminDTO ToAdmin(Promotion p, DateTime now, int granted, int used, int completed, decimal cost) => new()
        {
            Id = p.Id,
            Title = p.Title,
            Description = p.Description,
            Type = p.Type,
            Value = p.Value,
            MaxDiscount = p.MaxDiscount,
            Audience = p.Audience,
            Code = p.Code,
            RidesPerRider = p.RidesPerRider,
            RiderLimit = p.RiderLimit,
            IsActive = p.IsActive,
            StartsAt = p.StartsAt,
            EndsAt = p.EndsAt,
            CreatedAt = p.CreatedAt,
            IsRunning = p.IsActive && (p.StartsAt == null || p.StartsAt <= now) && (p.EndsAt == null || p.EndsAt >= now),
            GrantedRiders = granted,
            RidesUsed = used,
            RidesCompleted = completed,
            CompanyCost = cost,
        };

        private async Task<PromotionAdminDTO> GetOneAsync(int id)
            => (await GetAllAsync()).First(p => p.Id == id);

        private async Task<string?> ValidateAsync(SavePromotionDTO dto, int? id)
        {
            dto.Title = (dto.Title ?? "").Trim();
            dto.Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim();
            dto.Code = string.IsNullOrWhiteSpace(dto.Code) ? null : dto.Code.Trim().ToUpperInvariant();

            if (dto.Title.Length is < 2 or > 120) return "اكتب اسم العرض (من 2 إلى 120 حرف)";
            if (dto.Description?.Length > 500) return "الوصف طويل جداً (500 حرف كحد أقصى)";
            if (!Enum.IsDefined(dto.Type)) return "نوع العرض غير صحيح";
            if (!Enum.IsDefined(dto.Audience)) return "الفئة المستهدفة غير صحيحة";

            switch (dto.Type)
            {
                case PromotionType.FreeRide:
                    dto.Value = 0;
                    dto.MaxDiscount = null;
                    break;
                case PromotionType.PercentOff:
                    if (dto.Value is < 1 or > 100) return "نسبة الخصم يجب أن تكون بين 1 و 100";
                    if (dto.MaxDiscount is <= 0) return "الحد الأقصى للخصم يجب أن يكون أكبر من صفر";
                    break;
                case PromotionType.AmountOff:
                    if (dto.Value is < 1 or > 10000) return "قيمة الخصم يجب أن تكون بين 1 و 10000 ج.م";
                    dto.MaxDiscount = null;
                    break;
            }

            if (dto.Audience == PromotionAudience.PromoCode)
            {
                if (dto.Code == null || !CodePattern.IsMatch(dto.Code))
                    return "الكود من 3 إلى 32 حرف إنجليزي أو رقم (بدون مسافات)";
                if (await _context.Promotions.AnyAsync(p => p.Code == dto.Code && p.Id != (id ?? 0)))
                    return "هذا الكود مستخدم في عرض آخر";
            }
            else
            {
                dto.Code = null;
            }

            if (dto.RidesPerRider is < 1 or > 50) return "عدد الرحلات لكل عميل يجب أن يكون بين 1 و 50";
            if (dto.RiderLimit is < 1 or > 1_000_000) return "الحد الأقصى للعملاء يجب أن يكون بين 1 و 1000000";
            if (dto.StartsAt != null && dto.EndsAt != null && dto.EndsAt <= dto.StartsAt)
                return "تاريخ النهاية يجب أن يكون بعد تاريخ البداية";
            return null;
        }

        private static void Apply(Promotion p, SavePromotionDTO dto)
        {
            p.Title = dto.Title;
            p.Description = dto.Description;
            p.Type = dto.Type;
            p.Value = dto.Value;
            p.MaxDiscount = dto.MaxDiscount;
            p.Audience = dto.Audience;
            p.Code = dto.Code;
            p.RidesPerRider = dto.RidesPerRider;
            p.RiderLimit = dto.RiderLimit;
            p.IsActive = dto.IsActive;
            p.StartsAt = dto.StartsAt;
            p.EndsAt = dto.EndsAt;
        }

        public async Task<Response<PromotionAdminDTO>> CreateAsync(SavePromotionDTO dto)
        {
            var error = await ValidateAsync(dto, null);
            if (error != null) return Response<PromotionAdminDTO>.Failure(error, 400);

            var promo = new Promotion { CreatedAt = Now };
            Apply(promo, dto);
            _context.Promotions.Add(promo);
            await _context.SaveChangesAsync();
            return Response<PromotionAdminDTO>.Success(await GetOneAsync(promo.Id), "تم إنشاء العرض", 201);
        }

        public async Task<Response<PromotionAdminDTO>> UpdateAsync(int id, SavePromotionDTO dto)
        {
            var promo = await _context.Promotions.FindAsync(id);
            if (promo == null) return Response<PromotionAdminDTO>.Failure("العرض غير موجود", 404);
            var error = await ValidateAsync(dto, id);
            if (error != null) return Response<PromotionAdminDTO>.Failure(error, 400);

            Apply(promo, dto);
            promo.UpdatedAt = Now;
            await _context.SaveChangesAsync();
            return Response<PromotionAdminDTO>.Success(await GetOneAsync(id), "تم حفظ العرض", 200);
        }

        public async Task<Response<PromotionAdminDTO>> SetActiveAsync(int id, bool active)
        {
            var promo = await _context.Promotions.FindAsync(id);
            if (promo == null) return Response<PromotionAdminDTO>.Failure("العرض غير موجود", 404);
            promo.IsActive = active;
            promo.UpdatedAt = Now;
            await _context.SaveChangesAsync();
            return Response<PromotionAdminDTO>.Success(await GetOneAsync(id), active ? "تم تشغيل العرض" : "تم إيقاف العرض", 200);
        }

        public async Task<Response<string>> DeleteAsync(int id)
        {
            var promo = await _context.Promotions.FindAsync(id);
            if (promo == null) return Response<string>.Failure("العرض غير موجود", 404);
            if (await _context.Trips.AnyAsync(t => t.PromotionId == id))
                return Response<string>.Failure("العرض استُخدم في رحلات، أوقفه بدل حذفه", 400);
            _context.Promotions.Remove(promo);
            await _context.SaveChangesAsync();
            return Response<string>.Success("تم حذف العرض", "تم حذف العرض", 200);
        }
    }
}
