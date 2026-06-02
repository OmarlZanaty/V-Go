using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class UserDevice
    {
        public int Id { get; set; }
        public string? DeviceToken { get; set; } 

        public string? DeviceType { get; set; }  // Android / iOS 
        public DateTime? LastActive { get; set; } 
        public DateTime CreatedAt { get; set; }
        public bool IsActive { get; set; }
        public bool IsDeletd { get; set; } 

        [ForeignKey("User")]
        public string UserId { get; set; }
        public ApplicationUser User { get; set; }
    }
}
