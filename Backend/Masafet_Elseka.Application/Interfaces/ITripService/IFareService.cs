using Masafet_Elseka.Application.DTOs.Trip;

namespace Masafet_Elseka.Application.Interfaces.ITripService
{
    // Single source of truth for trip distance and price. Never trust a
    // distance sent by the app.
    public interface IFareService
    {
        // Null when no price per km is configured.
        Task<FareQuoteDTO?> QuoteAsync(double startLat, double startLng, double endLat, double endLng, CancellationToken ct = default);
    }
}
