namespace Masafet_Elseka.Domain.Enums
{
    // Every money movement on a captain's account. Amounts are signed:
    // positive = the company owes the captain, negative = the captain owes the company.
    public enum LedgerEntryType
    {
        TripCashCommission = 1, // cash trip: captain kept the fare, owes the company its commission (-)
        TripCardEarning = 2,    // card/wallet trip: company collected the fare, owes the captain his share (+)
        TripCorrection = 3,     // reverses an earlier trip entry when the trip's settlement changed
        Settlement = 4,         // captain paid his debt to the company through Paymob (+)
        Payout = 5,             // company transferred the captain's balance to him (-)
        Adjustment = 6,         // manual bonus / penalty by an admin, always with a reason (+/-)
        WalletCollection = 7    // captain transferred his dues to a company wallet, confirmed by the receipt SMS (+)
    }

    // What a Payment row is for. Trip payments keep the default so existing rows are unaffected.
    public enum PaymentPurpose
    {
        Trip = 0,
        CardVerification = 1,
        DriverSettlement = 2
    }

    public enum DriverVerificationStatus
    {
        PendingDocuments = 0, // registered, still uploading
        UnderReview = 1,      // everything uploaded, waiting for an admin
        Approved = 2,
        Rejected = 3,         // at least one document rejected; captain must re-upload
        Suspended = 4         // stopped by an admin
    }

    public enum DriverDocumentType
    {
        Selfie = 1,
        NationalIdFront = 2,
        NationalIdBack = 3,
        DriverLicense = 4,
        VehicleLicense = 5
    }

    public enum DriverDocumentStatus
    {
        Pending = 0,
        Approved = 1,
        Rejected = 2
    }

    public enum PayoutMethod
    {
        InstaPay = 1,
        MobileWallet = 2
    }
}
