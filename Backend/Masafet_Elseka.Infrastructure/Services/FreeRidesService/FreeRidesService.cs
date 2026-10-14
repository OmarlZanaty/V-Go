using Masafet_Elseka.Application.DTOs.FreeRides;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Application.Interfaces.IFreeRidesService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace Masafet_Elseka.Infrastructure.Services.FreeRidesService
{
    public class FreeRidesService : IFreeRidesService
    {
        private readonly Context _context;

        public FreeRidesService(Context context)
        {
            _context = context;
        }

        private async Task<PricingRule> GetRuleForUpdateAsync()
        {
            var rule = await _context.PricingRules.OrderBy(r => r.Id).FirstOrDefaultAsync();
            if (rule != null)
                return rule;

            rule = new PricingRule { LastUpdated = DateTime.Now.ToEgyptTime() };
            _context.PricingRules.Add(rule);
            await _context.SaveChangesAsync();
            return rule;
        }

        private async Task<PricingRule> GetRuleAsync()
        {
            return await _context.PricingRules.AsNoTracking().OrderBy(r => r.Id).FirstOrDefaultAsync()
                ?? new PricingRule();
        }

        private async Task AcquirePromoLockAsync()
        {
            await _context.Database.ExecuteSqlRawAsync(
                "DECLARE @r int; EXEC @r = sp_getapplock @Resource = {0}, @LockMode = 'Exclusive', " +
                "@LockOwner = 'Transaction', @LockTimeout = 15000; " +
                "IF @r < 0 THROW 51001, 'free rides promo lock timeout', 1;",
                "free-rides-promo");
        }

        public async Task GrantToNewClientAsync(ApplicationUser user)
        {
            if (user == null || string.IsNullOrWhiteSpace(user.Id) || user.FreeRidesGranted > 0)
                return;

            if (_context.Database.CurrentTransaction != null)
            {
                await GrantInsideCurrentTransactionAsync(user);
                return;
            }

            await using var tx = await _context.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            await GrantInsideCurrentTransactionAsync(user);
            await tx.CommitAsync();
        }

        private async Task GrantInsideCurrentTransactionAsync(ApplicationUser user)
        {
            await AcquirePromoLockAsync();

            var rule = await GetRuleForUpdateAsync();
            if (!rule.FreeRidesEnabled || rule.FreeRidesPerRider <= 0 || rule.FreeRidesRiderLimit <= 0)
                return;

            var grantedRiders = await _context.Users.IgnoreQueryFilters()
                .CountAsync(u => u.FreeRidesGranted > 0);
            if (grantedRiders >= rule.FreeRidesRiderLimit)
                return;

            user.FreeRidesGranted = rule.FreeRidesPerRider;
            _context.Users.Update(user);
            await _context.SaveChangesAsync();
        }

        public async Task<FreeRidesStatusDTO> GetStatusAsync(string userId)
        {
            var rule = await GetRuleAsync();
            var granted = string.IsNullOrWhiteSpace(userId)
                ? 0
                : await _context.Users.IgnoreQueryFilters()
                    .Where(u => u.Id == userId)
                    .Select(u => u.FreeRidesGranted)
                    .FirstOrDefaultAsync();

            var used = string.IsNullOrWhiteSpace(userId)
                ? 0
                : await _context.Trips
                    .Where(t => t.IsFreeRide &&
                        t.Status != TripStatus.Canceled &&
                        t.UserTrips.Any(ut => ut.UserId == userId && ut.Role == UserTripRole.Client))
                    .CountAsync();

            var remaining = rule.FreeRidesEnabled ? Math.Max(0, granted - used) : 0;
            return new FreeRidesStatusDTO
            {
                Enabled = rule.FreeRidesEnabled,
                Granted = granted,
                Used = used,
                Remaining = remaining
            };
        }

        public async Task<bool> HasFreeRideAvailableAsync(string? userId)
        {
            if (string.IsNullOrWhiteSpace(userId))
                return false;

            var status = await GetStatusAsync(userId);
            return status.Enabled && status.Remaining > 0;
        }

        public async Task<Response<FreeRidesAdminSettingsDTO>> GetAdminSettingsAsync()
        {
            return Response<FreeRidesAdminSettingsDTO>.Success(await BuildAdminSettingsAsync(), "", 200);
        }

        public async Task<Response<FreeRidesAdminSettingsDTO>> UpdateAdminSettingsAsync(UpdateFreeRidesSettingsDTO dto)
        {
            if (dto.PerRider is < 0 or > 10)
                return Response<FreeRidesAdminSettingsDTO>.Failure("عدد الرحلات المجانية لكل راكب يجب أن يكون بين 0 و 10", 400);
            if (dto.RiderLimit is < 0 or > 100000)
                return Response<FreeRidesAdminSettingsDTO>.Failure("حد الركاب يجب أن يكون بين 0 و 100000", 400);

            var rule = await GetRuleForUpdateAsync();
            rule.FreeRidesEnabled = dto.Enabled;
            rule.FreeRidesPerRider = dto.PerRider;
            rule.FreeRidesRiderLimit = dto.RiderLimit;
            rule.LastUpdated = DateTime.Now.ToEgyptTime();
            await _context.SaveChangesAsync();

            return Response<FreeRidesAdminSettingsDTO>.Success(await BuildAdminSettingsAsync(), "تم حفظ إعدادات الرحلات المجانية", 200);
        }

        private async Task<FreeRidesAdminSettingsDTO> BuildAdminSettingsAsync()
        {
            var rule = await GetRuleAsync();
            var freeTrips = _context.Trips.Where(t => t.IsFreeRide);

            return new FreeRidesAdminSettingsDTO
            {
                Enabled = rule.FreeRidesEnabled,
                PerRider = rule.FreeRidesPerRider,
                RiderLimit = rule.FreeRidesRiderLimit,
                GrantedRiders = await _context.Users.IgnoreQueryFilters().CountAsync(u => u.FreeRidesGranted > 0),
                FreeRidesUsed = await freeTrips.CountAsync(t => t.Status != TripStatus.Canceled),
                FreeRidesCompleted = await freeTrips.CountAsync(t => t.Status == TripStatus.Completed),
                CompanyCost = await _context.DriverLedgerEntries
                    .Where(e => e.Type == LedgerEntryType.TripFreeRideEarning)
                    .SumAsync(e => (decimal?)e.Amount) ?? 0m
            };
        }
    }
}
