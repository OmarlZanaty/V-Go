using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Chat
{
    public class ChatClosingDTO
    {
        public string User1Id { get; set; }
        public string User1Role { get; set; } = "Client";
        public string User2Id { get; set; }
        public string User2Role { get; set; } = "Dispatcher";
    }
}
