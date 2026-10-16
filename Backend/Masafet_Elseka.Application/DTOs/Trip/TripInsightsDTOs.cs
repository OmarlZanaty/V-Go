namespace Masafet_Elseka.Application.DTOs.Trip
{
    // A ~400 m grid cell with many recent pickups, for the captain map.
    public class HotspotDTO
    {
        public double Lat { get; set; }
        public double Lng { get; set; }
        public int Count { get; set; }
        public int Level { get; set; } // 1..3
    }

    public class TripCountsDTO
    {
        public int Total { get; set; }
        public int Completed { get; set; }
        public int Cancelled { get; set; }
        public int Active { get; set; }
        public int Cash { get; set; }
        public int Online { get; set; }
        public int CompletedCash { get; set; }
        public int CompletedOnline { get; set; }
        public int CancelledCash { get; set; }
        public int CancelledOnline { get; set; }
        public int Free { get; set; }
        // Trips that used an offer (free or discounted).
        public int WithOffer { get; set; }
    }

    public class DailyRevenueRowDTO
    {
        public DateTime Date { get; set; }
        public int Trips { get; set; }
        public int CashTrips { get; set; }
        public int OnlineTrips { get; set; }
        public int FreeTrips { get; set; }
        public decimal Total { get; set; }
        public decimal Cash { get; set; }
        public decimal Online { get; set; }
        public decimal CompanyCommission { get; set; }
        // Offer discounts the company paid on these trips.
        public decimal Discounts { get; set; }
    }

    public class DailyRevenueDTO
    {
        public List<DailyRevenueRowDTO> Days { get; set; } = new();
        public DailyRevenueRowDTO Totals { get; set; } = new();
    }
}
