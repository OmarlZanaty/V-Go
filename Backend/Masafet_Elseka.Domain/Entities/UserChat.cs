using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class UserChat
    {
        public string Id { get; set; }

        public string Role { get; set; }

        public string UserId { get; set; }
        public string ChatId { get; set; }

        public virtual ApplicationUser User { get; set; }
        [JsonIgnore]
        public virtual Chat Chat { get; set; }
    }
}
