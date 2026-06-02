using Masafet_Elseka.Application.DTOs.Chat;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IChatService
{
    public interface IChatService
    {
        Task<Response<IEnumerable<DispatcherChatDTO>>> GetSupportChatsByDispatcherIdAsync(string dispatcherId, bool isOpen);
        Task<Response<ChatDTO>> GetByIdAsync(string chatId);
        Task<Response<Chat>> CreateSupportChatAsync(string clientId);
        Task<Response<string>> CreateTripChat(string senderId, string reciverId, string tripId);
        Task<Response<ChatClosingDTO>> CloseChatAsync(string chatId);
        Task HandleUnClosedChats(CancellationToken cancellationToken);
        Task<Response<ChatDTO>> GetTripChat(string tripId, string senderId, string reciverId);
    }
}
