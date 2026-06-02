using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class Chat
    {
        public string Id { get; set; }
        public ChatType Type { get; set; }
        public bool IsOpen { get; set; } = true;
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        public string? TripId { get; set; }
        public virtual Trip? Trip { get; set; }

        [JsonIgnore]
        public virtual ICollection<Message> Messages { get; set; } = new List<Message>();
        [JsonIgnore]
        public virtual ICollection<UserChat> UserChats { get; set; } = new List<UserChat>();
    }
}
