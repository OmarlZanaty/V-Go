using System;
using System.Collections.Generic;
using Masafet_Elseka.Domain.Enums;

namespace Masafet_Elseka.Domain.Entities
{
    // A rider offer managed from the dashboard: free rides, a percentage off or a
    // fixed amount off, for new riders, all riders or whoever enters a code.
    // The company pays the discount: the captain's share is always taken from
    // the full fare.
    public class Promotion
    {
        public int Id { get; set; }
        // Shown to riders (Arabic), e.g. "أول رحلتين مجانًا".
        public string Title { get; set; } = "";
        public string? Description { get; set; }

        public PromotionType Type { get; set; }
        // Percent (PercentOff) or pounds (AmountOff); unused for FreeRide.
        public decimal Value { get; set; }
        // Upper limit of a percentage discount, in pounds; null = no limit.
        public decimal? MaxDiscount { get; set; }

        public PromotionAudience Audience { get; set; }
        // Upper-case code riders type in (PromoCode audience only).
        public string? Code { get; set; }

        // Discounted rides each rider gets from this offer.
        public int RidesPerRider { get; set; } = 1;
        // How many riders can join; null = no limit.
        public int? RiderLimit { get; set; }

        public bool IsActive { get; set; }
        // Optional campaign window (Egypt time); null = no limit on that side.
        public DateTime? StartsAt { get; set; }
        public DateTime? EndsAt { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }

        public virtual ICollection<PromotionGrant> Grants { get; set; } = new List<PromotionGrant>();
    }

    // A rider who joined an offer (signed up while it ran, entered its code, or
    // took a ride with it). The row is what the rider limit counts.
    public class PromotionGrant
    {
        public int Id { get; set; }
        public int PromotionId { get; set; }
        public string UserId { get; set; } = "";
        public DateTime GrantedAt { get; set; }

        public virtual Promotion Promotion { get; set; } = null!;
        public virtual ApplicationUser User { get; set; } = null!;
    }
}
