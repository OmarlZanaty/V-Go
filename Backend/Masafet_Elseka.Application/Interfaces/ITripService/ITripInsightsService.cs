using Masafet_Elseka.Application.DTOs.Trip;

namespace Masafet_Elseka.Application.Interfaces.ITripService
{
    // Read-only trip reports for the dashboard and the captain map.
    public interface ITripInsightsService
    {
        Task<List<HotspotDTO>> GetHotspotsAsync(int days, CancellationToken ct = default);
        Task<TripCountsDTO> GetCountsAsync(DateTime? from, DateTime? to, CancellationToken ct = default);
        Task<DailyRevenueDTO> GetDailyRevenueAsync(DateTime? from, DateTime? to, CancellationToken ct = default);
    }
}
