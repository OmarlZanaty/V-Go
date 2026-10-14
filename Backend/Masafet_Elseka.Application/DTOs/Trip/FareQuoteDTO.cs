namespace Masafet_Elseka.Application.DTOs.Trip
{
    // The fare the server will charge for a pickup → destination pair. The
    // client shows this before booking; AddTrip computes the same value.
    public class FareQuoteDTO
    {
        public double DistanceKm { get; set; }
        public decimal Price { get; set; }
        public decimal RiderPrice { get; set; }
        public bool IsFreeRide { get; set; }
        public int FreeRidesLeft { get; set; }
        // "osrm" = road distance; "estimate" = straight line × 1.3 when no router answered.
        public string Source { get; set; } = "osrm";
    }
}
