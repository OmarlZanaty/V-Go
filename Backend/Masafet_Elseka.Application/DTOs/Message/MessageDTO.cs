using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Message
{
    public class MessageDTO
    {
        public string Id { get; set; }
        public string Content { get; set; }
        public DateTime SendAt { get; set; }
        public string ChatId { get; set; }
        public string SenderId { get; set; }
        public string ReceiverId { get; set; }
    }
}
