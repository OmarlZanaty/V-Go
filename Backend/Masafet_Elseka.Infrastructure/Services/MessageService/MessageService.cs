using Masafet_Elseka.Application.DTOs.Message;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Interfaces.IChatService;
using Masafet_Elseka.Application.Interfaces.IMessageService;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.UOW;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using MimeKit;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.MessageService
{
    public class MessageService:IMessageService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly Context _context;
        private readonly IChatService _chatService;
        private readonly ICacheService _cacheService;
        private readonly ILogger<MessageService> _logger;
        private readonly INotificationService _notificationService;

        public MessageService(IUnitOfWork unitOfWork, Context context, IChatService chatService, ICacheService cacheService, ILogger<MessageService> logger, INotificationService notificationService)
        {
            _unitOfWork = unitOfWork;
            _context = context;
            _chatService = chatService;
            _cacheService = cacheService;
            _logger = logger;
            _notificationService = notificationService;
        }

        public async Task<Response<MessageDTO>> SendSupportMessageAsync(string? chatId, string senderId, string content)
        {
            if (string.IsNullOrEmpty(senderId) || string.IsNullOrEmpty(content))
            {
                return Response<MessageDTO>.Failure("البيانات التي تم إدخالها غير صالحة", 400);
            }

            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var chat = await _context.Chats.AsNoTracking()
                    .Include(c=>c.UserChats)
                    .FirstOrDefaultAsync(c => (c.IsOpen && c.Id==chatId!) || 
                    (c.IsOpen && (c.Id == chatId! || c.UserChats.Any(uc => uc.UserId == senderId))));
                if (chat is null)
                {
                    var newChatResponse = await _chatService.CreateSupportChatAsync(senderId);
                    if (!newChatResponse.IsSuccess && newChatResponse.Data is null)
                    {
                        return Response<MessageDTO>.Failure(newChatResponse.Message, newChatResponse.StatusCode);
                    }

                    chat = newChatResponse.Data;
                }

                var userChat = await _unitOfWork.UserChats
                    .GetByExpressionAsync(uc => uc.UserId == senderId && uc.ChatId==chat.Id);
                if (userChat is null)
                {
                    return Response<MessageDTO>.Failure("المستخدم غير مسجل في هذه المحادثة", 403);
                }

                var message = new Message
                {
                    Id = Guid.NewGuid().ToString(),
                    ChatId = chat.Id,
                    UserId = senderId,
                    Content = content,
                    SendAt = DateTime.Now.ToEgyptTime()
                };
                await _unitOfWork.Message.AddAsync(message);
                await _unitOfWork.SaveAsync();

                var receiverId= chat.UserChats
                        .Where(uc => uc.UserId != senderId)
                        .Select(uc => uc.UserId).FirstOrDefault()!;

                await _notificationService.SendNotificationToUserAsync(receiverId, "رسالة جديدة", $"لديك رسالة جديدة:\n {content}");

                await transaction.CommitAsync();
                return Response<MessageDTO>.Success(new MessageDTO
                {
                    Id = message.Id,
                    SenderId = message.UserId,
                    ReceiverId = receiverId,
                    ChatId = message.ChatId,
                    Content = message.Content,
                    SendAt = message.SendAt
                }, "تم إرسال الرسالة بنجاح", 200);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return Response<MessageDTO>.Failure($"حدث خطأ أثناء إرسال الرسالة", 500);
            }
        }

        public async Task<Response<ICollection<MessageDTO>>> GetSupportChatMessagesAsync(string? chatId, string userId, int skip = 0, int take = 30)
        {
            try
            {
                var messages = new List<MessageDTO>();

                if (string.IsNullOrEmpty(chatId))
                {
                    var chat = await _context.Chats.AsNoTracking()
                    .Include(c => c.UserChats)
                    .FirstOrDefaultAsync(c => c.IsOpen && c.UserChats.Any(uc => uc.UserId == userId));
                    if (chat is null)
                    {
                        return Response<ICollection<MessageDTO>>.Failure("لا توجد محادثة مفتوحة، ابدأ الان", 404);
                    }
                    chatId = chat.Id;
                }

                messages = await _context.Messages
                    .Include(m => m.Chat.UserChats)
                    .Where(m => m.ChatId == chatId)
                    .OrderByDescending(m => m.SendAt)
                    .Skip(skip)
                    .Take(take)
                    .Select(m => new MessageDTO
                    {
                        Id = m.Id,
                        SenderId = m.UserId,
                        ReceiverId = m.Chat.UserChats.Where(uc => uc.UserId != m.UserId)
                        .Select(uc => uc.UserId).FirstOrDefault()!,
                        ChatId = m.ChatId,
                        Content = m.Content,
                        SendAt = m.SendAt
                    })
                    .ToListAsync();

                if (messages is null)
                {
                    return Response<ICollection<MessageDTO>>.Failure("معرف المحادثة خاطئ", 400);
                }

                if (!messages.Any())
                {
                    return Response<ICollection<MessageDTO>>.Success(new List<MessageDTO>(),"لا توجد رسائل في هذه المحادثة", 201);
                }

                return Response<ICollection<MessageDTO>>.Success(messages, "تم جلب الرسائل بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<ICollection<MessageDTO>>.Failure($"حدث خطأ أثناء جلب الرسائل", 500);
            }
        }

        public async Task<Response<MessageDTO>> SendTripMessage(string ChatId, string senderId,string reciverId,string content)
        {
            if (string.IsNullOrEmpty(ChatId) || string.IsNullOrEmpty(senderId) || string.IsNullOrEmpty(reciverId) || string.IsNullOrEmpty(content))
            {
                return Response<MessageDTO>.Failure("البيانات التي تم إدخالها غير صالحة", 400);
            }
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var chat = await _context.Chats.AsNoTracking()
                    .Include(c => c.UserChats)
                    .FirstOrDefaultAsync(c => c.Id == ChatId && c.IsOpen);
                if (chat is null)
                {
                    return Response<MessageDTO>.Failure("المحادثة غير موجودة أو مغلقة", 404);
                }
                var userChat = await _unitOfWork.UserChats
                    .GetByExpressionAsync(uc => uc.UserId == senderId && uc.ChatId == chat.Id);
                if (userChat is null)
                {
                    return Response<MessageDTO>.Failure("المستخدم غير مسجل في هذه المحادثة", 403);
                }
                var message = new Message
                {
                    Id = Guid.NewGuid().ToString(),
                    ChatId = chat.Id,
                    UserId = senderId,
                    Content = content,
                    SendAt = DateTime.Now.ToEgyptTime()
                };
                await _unitOfWork.Message.AddAsync(message);
                await _unitOfWork.SaveAsync();
                await transaction.CommitAsync();
                return Response<MessageDTO>.Success(new MessageDTO
                {
                    Id = message.Id,
                    SenderId = message.UserId,
                    ReceiverId = reciverId,
                    ChatId = message.ChatId,
                    Content = message.Content,
                    SendAt = message.SendAt
                }, "تم إرسال الرسالة بنجاح", 200);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return Response<MessageDTO>.Failure($"حدث خطأ أثناء إرسال الرسالة", 500);
            }
        }

        public async Task<bool> UpdateMessageStatus(string msgId, bool isReceived)
        {
            try
            {
                var message = await _unitOfWork.Message
                    .GetByIdAsync(msgId);
                if (message is null)
                    return false;

                message.IsReceived = isReceived;
                await _unitOfWork.Message.UpdateAsync(message);
                await _unitOfWork.SaveAsync();

                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error updating message status for message {msgId}: {ex.Message}");
                return false;
            }
        }

        public async Task<Response<List<MessageDTO>>> GetUnReceivedMessagesForDispatcherAsync(string reciverId)
        {
            try
            {
                var messages = await _context.Messages
                    .Include(m => m.Chat).ThenInclude(c => c.UserChats)
                    .Where(m => m.Chat.UserChats.Any(uc => uc.UserId != m.UserId) && !m.IsReceived)
                    .ToListAsync();

                if(messages is null || !messages.Any())
                {
                    return Response<List<MessageDTO>>.Failure(new List<MessageDTO>(),"لا توجد رسائل غير مستلمة", 404);
                }

                var reciverMessages = messages
                    .Select(m => new MessageDTO
                    {
                        Id = m.Id,
                        SenderId = m.UserId,
                        ReceiverId = reciverId,
                        ChatId = m.ChatId,
                        Content = m.Content,
                        SendAt = m.SendAt,
                    })
                    .ToList();
                return Response<List<MessageDTO>>.Success(reciverMessages, "تم جلب الرسائل بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<List<MessageDTO>>.Failure($"حدث خطأ أثناء جلب الرسائل", 500);
            }
        }
    }
}
