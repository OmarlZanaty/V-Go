using Masafet_Elseka.Application.DTOs.Message;
using Masafet_Elseka.Application.Response;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IMessageService
{
    public interface IMessageService
    {
        Task<Response<MessageDTO>> SendSupportMessageAsync(string? chatId, string senderId, string content);
        Task<Response<ICollection<MessageDTO>>> GetSupportChatMessagesAsync(string? chatId, string userId, int skip = 0, int take = 30);
        Task<Response<MessageDTO>> SendTripMessage(string ChatId, string senderId, string reciverId, string content);
        Task<bool> UpdateMessageStatus(string msgId, bool isReceived);
        Task<Response<List<MessageDTO>>> GetUnReceivedMessagesForDispatcherAsync(string reciverId);
        
    }
}
