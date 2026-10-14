using System.Globalization;
using System.Text.Json;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Application.Interfaces.ITripService;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Masafet_Elseka.Infrastructure.Services.TripService
{
    public class FareService : IFareService
    {
        // Same public router the apps fall back to, so quotes match the drawn route.
        private const string OsrmUrl = "https://router.project-osrm.org/route/v1/driving/";
        // Straight line → road approximation, same factor the apps use.
        private const double StraightLineFactor = 1.3;

        private readonly Context _context;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly ICacheService _cache;
        private readonly ILogger<FareService> _logger;

        public FareService(Context context, IHttpClientFactory httpClientFactory, ICacheService cache, ILogger<FareService> logger)
        {
            _context = context;
            _httpClientFactory = httpClientFactory;
            _cache = cache;
            _logger = logger;
        }

        public async Task<FareQuoteDTO?> QuoteAsync(double startLat, double startLng, double endLat, double endLng, CancellationToken ct = default)
        {
            var pricePerKm = await _context.PricingRules.AsNoTracking()
                .OrderBy(r => r.Id).Select(r => (decimal?)r.PricePerKm).FirstOrDefaultAsync(ct);
            if (pricePerKm == null) return null;

            var (distanceKm, source) = await GetDistanceKmAsync(startLat, startLng, endLat, endLng, ct);
            // Distance × price per km, rounded up — no opening fee and no minimum fare.
            var price = Math.Ceiling((decimal)distanceKm * pricePerKm.Value);
            return new FareQuoteDTO { DistanceKm = Math.Round(distanceKm, 3), Price = price, RiderPrice = price, Source = source };
        }

        // Cached per ~10 m so the quote the rider saw and the trip they book
        // resolve to the same distance even if OSRM is flaky in between.
        private async Task<(double km, string source)> GetDistanceKmAsync(double sLat, double sLng, double eLat, double eLng, CancellationToken ct)
        {
            var key = string.Create(CultureInfo.InvariantCulture,
                $"fare-dist:{sLat:F4},{sLng:F4};{eLat:F4},{eLng:F4}");
            var cached = _cache.GetData<CachedDistance>(key);
            if (cached != null) return (cached.Km, cached.Source);

            var km = await TryOsrmAsync(sLat, sLng, eLat, eLng, ct);
            if (km != null)
            {
                _cache.SetData(key, new CachedDistance { Km = km.Value, Source = "osrm" }, TimeSpan.FromMinutes(30));
                return (km.Value, "osrm");
            }

            var estimate = GeoHelper.CalculateDistance(sLat, sLng, eLat, eLng) * StraightLineFactor;
            // Short TTL so a recovered router replaces the estimate soon.
            _cache.SetData(key, new CachedDistance { Km = estimate, Source = "estimate" }, TimeSpan.FromMinutes(3));
            return (estimate, "estimate");
        }

        private async Task<double?> TryOsrmAsync(double sLat, double sLng, double eLat, double eLng, CancellationToken ct)
        {
            try
            {
                var url = string.Create(CultureInfo.InvariantCulture,
                    $"{OsrmUrl}{sLng},{sLat};{eLng},{eLat}?overview=false");
                var client = _httpClientFactory.CreateClient();
                client.Timeout = TimeSpan.FromSeconds(6);
                client.DefaultRequestHeaders.UserAgent.ParseAdd("VGo-Backend/1.0");
                using var response = await client.GetAsync(url, ct);
                if (!response.IsSuccessStatusCode) return null;

                using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
                if (!doc.RootElement.TryGetProperty("routes", out var routes) || routes.GetArrayLength() == 0)
                    return null;
                return routes[0].GetProperty("distance").GetDouble() / 1000.0;
            }
            catch (Exception ex) when (ex is not OperationCanceledException || !ct.IsCancellationRequested)
            {
                _logger.LogWarning(ex, "OSRM route lookup failed; using straight-line estimate");
                return null;
            }
        }

        private class CachedDistance
        {
            public double Km { get; set; }
            public string Source { get; set; } = "osrm";
        }
    }
}
