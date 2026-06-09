using Masafet_Elseka.Application.Interfaces.IChatService;
using Masafet_Elseka.Application.Interfaces.IDispatcherService;
using Masafet_Elseka.Application.Interfaces.IMessageService;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Hubs
{
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class SupportChatHub : Hub
    {
        private readonly IChatService _chatService;
        private readonly IMessageService _messageService;
        private readonly IDispatcherService _dispatcherService;
        private readonly ILogger<SupportChatHub> _logger;
        private static readonly ConcurrentDictionary<string, HashSet<string>> _usersConnectionMap = new();

        public SupportChatHub(IChatService chatService, IMessageService messageService, IDispatcherService dispatcherService, ILogger<SupportChatHub> logger)
        {
            _chatService = chatService;
            _messageService = messageService;
            _dispatcherService = dispatcherService;
            _logger = logger;
        }

        public override async Task OnConnectedAsync()
        {
            var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if(!string.IsNullOrEmpty(userId))
            {
                _usersConnectionMap.AddOrUpdate(
                    userId,
                    new HashSet<string> { Context.ConnectionId },
                    (key, connections) =>
                    {
                        lock (connections)
                        {
                            connections.Add(Context.ConnectionId);
                            return connections;
                        }
                    }
                );
            }
            if(Context.User?.FindFirst(ClaimTypes.Role)?.Value == "Dispatcher")
            {
                var isUpdated = await _dispatcherService.UpdateDispatcherAvailability(Context.UserIdentifier!, true);
                if (!isUpdated)
                {
                    _logger.LogError($"Failed to update dispatcher availability for user {Context.UserIdentifier!}", Context.UserIdentifier);
                }
                var unReceivedMessages = await _messageService.GetUnReceivedMessagesForDispatcherAsync(userId??"");
                foreach(var message in unReceivedMessages.Data)
                {
                    await _messageService.UpdateMessageStatus(message.Id, true);
                    await Clients.Caller.SendAsync("ReceiveSupportMessage", message);
                }
            }

            await base.OnConnectedAsync();
        }

        public async Task SendSupportMessage(string senderId, string content, string? chatId = null)
        {
            var response = await _messageService.SendSupportMessageAsync(chatId, senderId, content);
            if (!response.IsSuccess)
            {
                _logger.LogError("Failed to send support message for chat {ChatId} by user {SenderId}", chatId!, senderId);
                throw new Exception(response.Message);
            }
            //var receiverIds = _usersConnectionMap[response.Data.ReceiverId];
            await _messageService.UpdateMessageStatus(response.Data.Id, true);
            _logger.LogInformation($"receiver id: {response.Data.ReceiverId} <---> {response.Data.Content}");
            await Clients.User(response.Data.ReceiverId).SendAsync("ReceiveSupportMessage", response.Data);
        }

        public async Task CloseChat(string chatId)
        {
            var response = await _chatService.CloseChatAsync(chatId);
            if (!response.IsSuccess)
            {
                _logger.LogError("Failed to close chat {ChatId}: {Message}", chatId, response.Message);
                throw new Exception(response.Message);
            }
            await Clients.Users(response.Data.User1Id, response.Data.User2Id).SendAsync("ChatClosed", chatId);
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!string.IsNullOrEmpty(userId))
            {
                if(_usersConnectionMap.TryGetValue(userId, out var userConnections))
                {
                    lock (userConnections)
                    {
                        userConnections.Remove(Context.ConnectionId);
                        if (userConnections.Count == 0)
                            _usersConnectionMap.TryRemove(userId, out _);
                        _logger.LogInformation("user with Id {UserId} disconnect from ConnectionId: {Context.ConnectionId}.",userId,Context.ConnectionId);
                    }
                }
            }
            if (Context.User?.FindFirst(ClaimTypes.Role)?.Value == "Dispatcher")
            {
                var isUpdated = await _dispatcherService.UpdateDispatcherAvailability(Context.UserIdentifier!, false);
                if (!isUpdated)
                {
                    _logger.LogError(new Exception("Failed to update dispatcher availability"), "Failed to update dispatcher availability for user {UserId}", Context.UserIdentifier);
                }
            }
            await base.OnDisconnectedAsync(exception);
        }
    }
}
