using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Dispatcher
{
    public class DispatcherDTO
    {
        public string Id { get; set; }
        public bool IsAvailable { get; set; }
        public DateTime? LastHandledChatAt { get; set; } = DateTime.UtcNow;
    }
}
