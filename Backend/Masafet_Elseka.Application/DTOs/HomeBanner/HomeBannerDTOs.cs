namespace Masafet_Elseka.Application.DTOs.HomeBanner
{
    // What the rider app needs to draw the carousel.
    public class ActiveBannerDTO
    {
        public int Id { get; set; }
        public string ImageUrl { get; set; } = string.Empty;
        // "image" or "video" (an MP4 that plays muted in the carousel).
        public string MediaType { get; set; } = "image";
        public string? LinkUrl { get; set; }
    }

    public class AdminBannerDTO
    {
        public int Id { get; set; }
        public string ImageUrl { get; set; } = string.Empty;
        public string MediaType { get; set; } = "image";
        public int Position { get; set; }
        public string? Title { get; set; }
        public string? LinkUrl { get; set; }
        public bool IsActive { get; set; }
        public DateTime? StartsAt { get; set; }
        public DateTime? EndsAt { get; set; }
        // Active + inside its date window right now = visible in the app.
        public bool IsLive { get; set; }
        public int ClickCount { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }

    // multipart/form-data for create (image required) and update (image optional).
    public class SaveBannerDTO
    {
        public string? Title { get; set; }
        public string? LinkUrl { get; set; }
        public bool IsActive { get; set; } = true;
        public DateTime? StartsAt { get; set; }
        public DateTime? EndsAt { get; set; }
    }
}
