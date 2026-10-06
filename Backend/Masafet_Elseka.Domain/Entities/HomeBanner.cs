using System;

namespace Masafet_Elseka.Domain.Entities
{
    // An ad slot in the rider app's home carousel, managed from the dashboard.
    public class HomeBanner
    {
        public int Id { get; set; }
        public string ImageUrl { get; set; }
        // Carousel order, ascending.
        public int Position { get; set; }

        // Admin-facing label (advertiser / campaign); never shown in the app.
        public string? Title { get; set; }
        // Optional http(s) link opened when the rider taps the banner.
        public string? LinkUrl { get; set; }
        public bool IsActive { get; set; } = true;
        // Optional campaign window; null = no limit on that side.
        public DateTime? StartsAt { get; set; }
        public DateTime? EndsAt { get; set; }
        public int ClickCount { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}
