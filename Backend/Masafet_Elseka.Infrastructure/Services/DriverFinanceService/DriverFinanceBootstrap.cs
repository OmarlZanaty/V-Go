using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace Masafet_Elseka.Infrastructure.Services.DriverFinanceService
{
    // Runs once, on the first start of the version that introduced captain finance:
    //  - ledgers start from zero now (older trips are never posted);
    //  - captains who were already working stay approved, with 7 days to upload
    //    their documents before they're kept offline.
    public static class DriverFinanceBootstrap
    {
        public const int GraceDays = 7;

        public static async Task RunAsync(Context db)
        {
            var rule = await db.PricingRules.OrderBy(r => r.Id).FirstOrDefaultAsync();
            if (rule == null || rule.LedgerStartAt != null) return;

            var now = DateTime.Now.ToEgyptTime();
            var driverIds = from ur in db.UserRoles
                            join r in db.Roles on ur.RoleId equals r.Id
                            where r.Name == "Driver"
                            select ur.UserId;

            var grandfathered = await db.Users.IgnoreQueryFilters()
                .Where(u => driverIds.Contains(u.Id) && u.VerificationStatus == DriverVerificationStatus.PendingDocuments)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(u => u.VerificationStatus, DriverVerificationStatus.Approved)
                    .SetProperty(u => u.DocumentsDeadline, now.AddDays(GraceDays)));

            rule.LedgerStartAt = now;
            await db.SaveChangesAsync();
            Log.Information("Driver finance launched at {Start}; {Count} existing captains approved with a {Days}-day document grace period",
                now, grandfathered, GraceDays);
        }
    }
}
