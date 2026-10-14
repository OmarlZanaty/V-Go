namespace Masafet_Elseka.Application.DTOs.FreeRides
{
    public class FreeRidesStatusDTO
    {
        public bool Enabled { get; set; }
        public int Granted { get; set; }
        public int Used { get; set; }
        public int Remaining { get; set; }
    }

    public class FreeRidesAdminSettingsDTO
    {
        public bool Enabled { get; set; }
        public int PerRider { get; set; }
        public int RiderLimit { get; set; }
        public int GrantedRiders { get; set; }
        public int FreeRidesUsed { get; set; }
        public int FreeRidesCompleted { get; set; }
        public decimal CompanyCost { get; set; }
    }

    public class UpdateFreeRidesSettingsDTO
    {
        public bool Enabled { get; set; }
        public int PerRider { get; set; }
        public int RiderLimit { get; set; }
    }
}
