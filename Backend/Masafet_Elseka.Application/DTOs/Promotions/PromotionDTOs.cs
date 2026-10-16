using Masafet_Elseka.Domain.Enums;

namespace Masafet_Elseka.Application.DTOs.Promotions
{
    // The offer a trip / quote gets, with what it takes off the fare.
    public class PromotionQuote
    {
        public int PromotionId { get; set; }
        public string Title { get; set; } = "";
        public PromotionType Type { get; set; }
        public decimal Discount { get; set; }
        // Discounted rides the rider still has on this offer, this one included.
        public int RidesLeft { get; set; }
    }

    // An offer as the rider sees it in the app.
    public class MyPromotionDTO
    {
        public int Id { get; set; }
        public string Title { get; set; } = "";
        public string? Description { get; set; }
        public PromotionType Type { get; set; }
        public decimal Value { get; set; }
        public decimal? MaxDiscount { get; set; }
        public int RidesPerRider { get; set; }
        public int RidesUsed { get; set; }
        public int RidesLeft { get; set; }
        public DateTime? EndsAt { get; set; }
        public string? Code { get; set; }
    }

    public class RedeemPromotionDTO
    {
        public string Code { get; set; } = "";
    }

    public class PromotionAdminDTO
    {
        public int Id { get; set; }
        public string Title { get; set; } = "";
        public string? Description { get; set; }
        public PromotionType Type { get; set; }
        public decimal Value { get; set; }
        public decimal? MaxDiscount { get; set; }
        public PromotionAudience Audience { get; set; }
        public string? Code { get; set; }
        public int RidesPerRider { get; set; }
        public int? RiderLimit { get; set; }
        public bool IsActive { get; set; }
        public DateTime? StartsAt { get; set; }
        public DateTime? EndsAt { get; set; }
        public DateTime CreatedAt { get; set; }
        // Running now: active and inside its window.
        public bool IsRunning { get; set; }

        public int GrantedRiders { get; set; }
        public int RidesUsed { get; set; }
        public int RidesCompleted { get; set; }
        // Discounts the company paid on completed trips.
        public decimal CompanyCost { get; set; }
    }

    public class SavePromotionDTO
    {
        public string Title { get; set; } = "";
        public string? Description { get; set; }
        public PromotionType Type { get; set; }
        public decimal Value { get; set; }
        public decimal? MaxDiscount { get; set; }
        public PromotionAudience Audience { get; set; }
        public string? Code { get; set; }
        public int RidesPerRider { get; set; } = 1;
        public int? RiderLimit { get; set; }
        public bool IsActive { get; set; }
        public DateTime? StartsAt { get; set; }
        public DateTime? EndsAt { get; set; }
    }
}
