namespace Masafet_Elseka.Domain.Enums
{
    public enum PromotionType
    {
        FreeRide = 1,   // the rider pays nothing
        PercentOff = 2, // Value % off the fare (optionally capped by MaxDiscount)
        AmountOff = 3   // Value pounds off the fare
    }

    public enum PromotionAudience
    {
        NewRiders = 1, // riders who sign up while the offer runs
        AllRiders = 2, // every rider
        PromoCode = 3  // riders who enter the offer's code
    }
}
