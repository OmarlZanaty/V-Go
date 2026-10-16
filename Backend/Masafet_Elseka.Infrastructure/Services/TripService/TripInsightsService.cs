using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Application.Interfaces.ITripService;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Masafet_Elseka.Infrastructure.Services.TripService
{
    public class TripInsightsService : ITripInsightsService
    {
        // Pickups are grouped on a 0.004° grid (~400 m in Egypt).
        private const double Cell = 0.004;
        private const int MaxHotspots = 15;

        private readonly Context _context;
        private readonly ICacheService _cache;

        public TripInsightsService(Context context, ICacheService cache)
        {
            _context = context;
            _cache = cache;
        }

        private static bool IsOnline(string? method) =>
            string.Equals(method, "Visa", StringComparison.OrdinalIgnoreCase);

        public async Task<List<HotspotDTO>> GetHotspotsAsync(int days, CancellationToken ct = default)
        {
            days = Math.Clamp(days, 1, 60);
            var key = $"trip-hotspots:{days}";
            var cached = _cache.GetData<List<HotspotDTO>>(key);
            if (cached != null) return cached;

            var since = DateTime.Now.ToEgyptTime().AddDays(-days);
            var rows = await _context.Trips.AsNoTracking()
                .Where(t => t.CreatedAt >= since)
                .Select(t => new { t.StartLat, t.StartLng, t.Status, t.CreatedAt, t.EndTime })
                .ToListAsync(ct);

            var cells = rows
                // A request cancelled within a minute is usually a mistake, not demand.
                .Where(t => !(t.Status == TripStatus.Canceled && t.EndTime != null
                              && (t.EndTime.Value - t.CreatedAt).TotalMinutes < 1))
                .Where(t => t.StartLat != 0 && t.StartLng != 0)
                .GroupBy(t => (Math.Round(t.StartLat / Cell), Math.Round(t.StartLng / Cell)))
                .Select(g => new HotspotDTO
                {
                    // Centre on the real pickups, not the grid corner.
                    Lat = Math.Round(g.Average(t => t.StartLat), 5),
                    Lng = Math.Round(g.Average(t => t.StartLng), 5),
                    Count = g.Count(),
                })
                .Where(h => h.Count >= 2)
                .OrderByDescending(h => h.Count)
                .Take(MaxHotspots)
                .ToList();

            // Level by tercile of the counts shown (3 = busiest).
            for (var i = 0; i < cells.Count; i++)
                cells[i].Level = cells.Count < 3 ? 3 : 3 - (i * 3 / cells.Count);

            _cache.SetData(key, cells, TimeSpan.FromMinutes(10));
            return cells;
        }

        public async Task<TripCountsDTO> GetCountsAsync(DateTime? from, DateTime? to, CancellationToken ct = default)
        {
            var q = _context.Trips.AsNoTracking().AsQueryable();
            if (from != null) q = q.Where(t => t.CreatedAt >= from.Value.Date);
            if (to != null) q = q.Where(t => t.CreatedAt < to.Value.Date.AddDays(1));

            var rows = await q
                .GroupBy(t => new { t.Status, t.PaymentMethod, t.IsFreeRide, WithOffer = t.PromotionId != null })
                .Select(g => new { g.Key.Status, g.Key.PaymentMethod, g.Key.IsFreeRide, g.Key.WithOffer, Count = g.Count() })
                .ToListAsync(ct);

            int Sum(Func<TripStatus, bool> status, Func<string?, bool>? method = null) =>
                rows.Where(r => status(r.Status) && (method == null || method(r.PaymentMethod))).Sum(r => r.Count);
            static bool Active(TripStatus s) =>
                s is TripStatus.Pending or TripStatus.Accepted or TripStatus.Arrived or TripStatus.InProgress;

            return new TripCountsDTO
            {
                Total = rows.Sum(r => r.Count),
                Completed = Sum(s => s == TripStatus.Completed),
                Cancelled = Sum(s => s == TripStatus.Canceled),
                Active = Sum(Active),
                Cash = Sum(_ => true, m => !IsOnline(m)),
                Online = Sum(_ => true, IsOnline),
                CompletedCash = Sum(s => s == TripStatus.Completed, m => !IsOnline(m)),
                CompletedOnline = Sum(s => s == TripStatus.Completed, IsOnline),
                CancelledCash = Sum(s => s == TripStatus.Canceled, m => !IsOnline(m)),
                CancelledOnline = Sum(s => s == TripStatus.Canceled, IsOnline),
                Free = rows.Where(r => r.IsFreeRide).Sum(r => r.Count),
                WithOffer = rows.Where(r => r.WithOffer).Sum(r => r.Count),
            };
        }

        public async Task<DailyRevenueDTO> GetDailyRevenueAsync(DateTime? from, DateTime? to, CancellationToken ct = default)
        {
            var today = DateTime.Now.ToEgyptTime().Date;
            var end = (to ?? today).Date;
            var start = (from ?? end.AddDays(-29)).Date;
            if (start > end) (start, end) = (end, start);
            if ((end - start).TotalDays > 366) start = end.AddDays(-366);

            var trips = await _context.Trips.AsNoTracking()
                .Where(t => t.Status == TripStatus.Completed)
                .Where(t => (t.EndTime ?? t.CreatedAt) >= start && (t.EndTime ?? t.CreatedAt) < end.AddDays(1))
                .Select(t => new { t.Id, Day = (t.EndTime ?? t.CreatedAt).Date, t.Price, t.DiscountAmount, t.PaymentMethod, t.IsFreeRide })
                .ToListAsync(ct);

            // The company's commission as posted to the captain ledgers (latest entry per trip).
            var tripIds = trips.Select(t => t.Id).ToList();
            var commissions = (await _context.DriverLedgerEntries.AsNoTracking().IgnoreQueryFilters()
                    .Where(e => e.TripId != null && e.CommissionAmount != null && tripIds.Contains(e.TripId))
                    .Select(e => new { e.Id, e.TripId, e.CommissionAmount })
                    .ToListAsync(ct))
                .GroupBy(e => e.TripId!)
                .ToDictionary(g => g.Key, g => g.OrderBy(e => e.Id).Last().CommissionAmount ?? 0m);

            var byDay = trips.GroupBy(t => t.Day).ToDictionary(g => g.Key, g => g.ToList());
            var result = new DailyRevenueDTO();
            for (var day = end; day >= start; day = day.AddDays(-1))
            {
                var list = byDay.TryGetValue(day, out var l) ? l : new();
                // What riders paid: an offer's discount (all of a free ride) is the company's cost.
                var paid = list.Where(t => !t.IsFreeRide).ToList();
                var online = paid.Where(t => IsOnline(t.PaymentMethod)).Sum(t => t.Price - t.DiscountAmount);
                var total = paid.Sum(t => t.Price - t.DiscountAmount);
                result.Days.Add(new DailyRevenueRowDTO
                {
                    Date = day,
                    Trips = list.Count,
                    OnlineTrips = list.Count(t => IsOnline(t.PaymentMethod)),
                    CashTrips = list.Count(t => !IsOnline(t.PaymentMethod) && !t.IsFreeRide),
                    FreeTrips = list.Count(t => t.IsFreeRide),
                    Total = total,
                    Online = online,
                    Cash = total - online,
                    CompanyCommission = list.Sum(t => commissions.TryGetValue(t.Id, out var c) ? c : 0m),
                    Discounts = list.Sum(t => t.DiscountAmount),
                });
            }

            result.Totals = new DailyRevenueRowDTO
            {
                Date = start,
                Trips = result.Days.Sum(d => d.Trips),
                CashTrips = result.Days.Sum(d => d.CashTrips),
                OnlineTrips = result.Days.Sum(d => d.OnlineTrips),
                FreeTrips = result.Days.Sum(d => d.FreeTrips),
                Total = result.Days.Sum(d => d.Total),
                Cash = result.Days.Sum(d => d.Cash),
                Online = result.Days.Sum(d => d.Online),
                CompanyCommission = result.Days.Sum(d => d.CompanyCommission),
                Discounts = result.Days.Sum(d => d.Discounts),
            };
            return result;
        }
    }
}
