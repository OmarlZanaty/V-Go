namespace Masafet_Elseka.Application.DTOs.Trip
{
    // An earlier trip the rider refused to pay (reported by the captain). The
    // rider can't request a new trip until it's paid.
    public class OutstandingDebtDTO
    {
        public string TripId { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public DateTime? EndTime { get; set; }
    }
}
