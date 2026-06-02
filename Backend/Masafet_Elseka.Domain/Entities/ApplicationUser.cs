using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class ApplicationUser:IdentityUser
    {
        public string FullName { get; set; }
        public string Gender { get; set; }
        public string? LastLogin { get; set; }
        public string? ProfilePicture { get; set; }
        public string? NationalId { get; set; }
        public string? License { get; set; }
        public bool IsBlocked { get; set; }
        public bool? IsAvailable { get; set; }
        public DateTime? LastHandledChatAt { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public bool IsDeleted { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public virtual Scooter? Scooter { get; set; }
        public virtual ICollection<Message> Messages { get; set; }
        public virtual ICollection<UserChat> UserChats { get; set; }
        public virtual ICollection<Rate> RatingsGiven { get; set; } = new List<Rate>();
        public virtual ICollection<Rate> RatingsReceived { get; set; } = new List<Rate>();
        public virtual ICollection<UserTrip> UserTrips { get; set; } = new List<UserTrip>();
        public virtual ICollection<RefreshToken>? RefreshTokens { get; set; } = new List<RefreshToken>();
        public virtual ICollection<Payment>? Payments { get; set; } = new List<Payment>();
        public virtual ICollection<SavedCard>? SavedCards { get; set; } = new List<SavedCard>();
        public virtual ICollection<UserDevice> UserDevices { get; set; } = new List<UserDevice>();
        public virtual ICollection<Notification> Notifications { get; set; } = new List<Notification>();

    }
}
