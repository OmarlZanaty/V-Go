using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class Rate
    {

        public string Id { get; set; }
        public int Score { get; set; }
        public string? Comment { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;

        public string TripId { get; set; }
        public string FromUserId { get; set; }
        public string ToUserId { get; set; }

        // Navigation properties
        public virtual Trip Trip { get; set; }

        public virtual ApplicationUser FromUser { get; set; }
        public virtual ApplicationUser ToUser { get; set; }
    }
}
