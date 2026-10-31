using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System.Globalization;

namespace Masafet_Elseka.Infrastructure.Services.DispatchSettings
{
    // Captains only get trip offers whose pickup is within this straight-line
    // radius. Kept in AppSettings so the admin dashboard can change it without a
    // deploy; read on every offer, so it is cached for a few seconds.
    public interface IDispatchSettingsService
    {
        Task<double> GetRadiusKmAsync(CancellationToken ct = default);
        Task SetRadiusKmAsync(double radiusKm, CancellationToken ct = default);
    }

    public class DispatchSettingsService(IServiceScopeFactory scopes, ILogger<DispatchSettingsService> logger)
        : IDispatchSettingsService
    {
        public const string RadiusKey = "Dispatch.RadiusKm";
        public const double DefaultRadiusKm = 4.0;
        public const double MinRadiusKm = 0.5;
        public const double MaxRadiusKm = 50.0;
        private static readonly TimeSpan CacheFor = TimeSpan.FromSeconds(30);

        private double _radiusKm = DefaultRadiusKm;
        private DateTime _loadedAtUtc = DateTime.MinValue;

        public static bool IsValid(double radiusKm) => radiusKm >= MinRadiusKm && radiusKm <= MaxRadiusKm;

        public async Task<double> GetRadiusKmAsync(CancellationToken ct = default)
        {
            if (DateTime.UtcNow - _loadedAtUtc < CacheFor)
                return _radiusKm;
            try
            {
                using var scope = scopes.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<Context>();
                var value = await db.AppSettings.AsNoTracking()
                    .Where(s => s.Key == RadiusKey).Select(s => s.Value).FirstOrDefaultAsync(ct);
                _radiusKm = double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var km) && IsValid(km)
                    ? km
                    : DefaultRadiusKm;
                _loadedAtUtc = DateTime.UtcNow;
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                // Keep dispatching with the last known radius rather than failing the offer.
                logger.LogWarning(ex, "Could not read {Key}; using {Radius} km", RadiusKey, _radiusKm);
            }
            return _radiusKm;
        }

        public async Task SetRadiusKmAsync(double radiusKm, CancellationToken ct = default)
        {
            using var scope = scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<Context>();
            var setting = await db.AppSettings.FindAsync(new object[] { RadiusKey }, ct);
            if (setting == null)
            {
                setting = new AppSetting { Key = RadiusKey };
                db.AppSettings.Add(setting);
            }
            setting.Value = radiusKm.ToString(CultureInfo.InvariantCulture);
            setting.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);
            _radiusKm = radiusKm;
            _loadedAtUtc = DateTime.UtcNow;
        }
    }
}
