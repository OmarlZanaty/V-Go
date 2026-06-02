using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Chat
{
    public class DispatcherChatDTO
    {
        public string Id { get; set; }
        public bool IsOpen { get; set; }
        public string ClientName { get; set; }
        public string ClientId { get; set; }
        public string ProfilePicture { get; set; }
    }
}
