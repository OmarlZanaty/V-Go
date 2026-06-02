using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class UserTrip
    {
        public string Id { get; set; }
        public bool IsApproved { get; set; }
        public DateTime Date { get; set; }
        public UserTripRole Role { get; set; }

        [ForeignKey("User")]
        public string UserId { get; set; }
        public string TripId { get; set; }

        public virtual ApplicationUser User { get; set; }
        public virtual Trip Trip { get; set; }


    }
}
