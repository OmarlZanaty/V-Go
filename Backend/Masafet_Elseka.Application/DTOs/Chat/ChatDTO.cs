using Masafet_Elseka.Application.DTOs.Message;
using Masafet_Elseka.Application.DTOs.UserChat;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Chat
{
    public class ChatDTO
    {
        public string Id { get; set; }
        public ChatType Type { get; set; }
        public bool IsOpen { get; set; }
        public DateTime CreatedAt { get; set; }
        public string? TripId { get; set; }
        public List<MessageDTO> Messages { get; set; } = new List<MessageDTO>();
        public List<UserChatDTO> UserChats { get; set; } = new List<UserChatDTO>();
    }
}
