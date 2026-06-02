using Masafet_Elseka.Application.Interfaces.IChatService;
using Masafet_Elseka.Application.Interfaces.IMessageService;
using Microsoft.AspNetCore.SignalR;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Hubs
{
    public class TripChatHub : Hub
    {
        private readonly IChatService _chatService;
        private readonly IMessageService _messageService;
        public TripChatHub(IChatService chatService, IMessageService messageService)
        {
            _chatService = chatService;
            _messageService = messageService;
        }

        public override Task OnConnectedAsync()
        {
            return base.OnConnectedAsync();
        }
        public async Task JoinChat(string chatId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, chatId);
            await Clients.Caller.SendAsync("ReceiveJoined", chatId);
        }

        public override Task OnDisconnectedAsync(Exception? exception)
        {
            return base.OnDisconnectedAsync(exception);
        }

        public async Task<string> SendMessage(string senderId, string receiverId, string tripId, string message)
        {
            if (string.IsNullOrEmpty(senderId) || string.IsNullOrEmpty(receiverId)
                || string.IsNullOrEmpty(tripId) || string.IsNullOrEmpty(message))
            {
                await Clients.Caller.SendAsync("ReceiveError", "برجاء التاكد من صحة البيانات");
                return "Invalid input parameters.";
            }

            string chatId;

   
            var existingChat = await _chatService.GetTripChat(tripId, senderId, receiverId);

            if ( existingChat.Data == null)
            {

                var createdChat = await _chatService.CreateTripChat(senderId, receiverId, tripId);
                if (!createdChat.IsSuccess || createdChat.Data == null)
                {
                    await Clients.Caller.SendAsync("ReceiveError", "فشل إنشاء المحادثة");
                    return "Chat creation failed.";
                }

                chatId = createdChat.Data;

               
                await Clients.User(senderId).SendAsync("ReceiveChat", createdChat.Data);
                await Clients.User(receiverId).SendAsync("ReceiveChat", createdChat.Data);
            }
            else
            {
                chatId = existingChat.Data.Id;
            }

        
            var result = await _messageService.SendTripMessage(chatId, senderId, receiverId, message);
            if (result.IsSuccess)
            {
                
                await Groups.AddToGroupAsync(Context.ConnectionId, chatId);

               
                await Clients.Group(chatId).SendAsync("ReceiveMessage", result.Data);
                return "Message sent successfully.";
            }

            await Clients.Caller.SendAsync("ReceiveError", "فشل إرسال الرسالة");
            return "Message sending failed.";
        }




    }
}

