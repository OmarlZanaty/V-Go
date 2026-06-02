using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Entities
{
    public class Message
    {
        public string Id { get; set; }

        public string Content { get; set; }
        public DateTime SendAt { get; set; }
        public bool IsReceived { get; set; }
        public string UserId { get; set; }  
        public virtual ApplicationUser User { get; set; }

        public string ChatId { get; set; }
        public virtual Chat Chat { get; set; }
    }
}
