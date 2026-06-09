using Masafet_Elseka.Application.DTOs.Chat;
using Masafet_Elseka.Application.DTOs.Dispatcher;
using Masafet_Elseka.Application.DTOs.UserChat;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Interfaces.IChatService;
using Masafet_Elseka.Application.Interfaces.IDispatcherService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.UOW;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using MimeKit;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.ChatService
{
    public class ChatService:IChatService
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly Context _context;
        private readonly IDispatcherService _dispatcherService;
        private readonly ILogger<ChatService> _logger;
        private readonly ICacheService _cacheService;

        public ChatService(IUnitOfWork unitOfWork, Context context, UserManager<ApplicationUser> userManager, IDispatcherService dispatcherService, ILogger<ChatService> logger, ICacheService cacheService)
        {
            _unitOfWork = unitOfWork;
            _context = context;
            _userManager = userManager;
            _dispatcherService = dispatcherService;
            _logger = logger;
            _cacheService = cacheService;
        }

        public async Task<Response<IEnumerable<DispatcherChatDTO>>> GetSupportChatsByDispatcherIdAsync(string dispatcherId, bool isOpen = true)
        {
            try
            {
                var chats = await _context.Chats.AsNoTracking()
                    .Where(c => c.Type == ChatType.SupportChat && c.IsOpen == isOpen
                    && c.UserChats.Any(uc => uc.UserId == dispatcherId))
                    .Select(c => new
                    {
                        c.Id,
                        c.IsOpen,
                        UserChats = c.UserChats
                        .Where(uc => uc.UserId != dispatcherId)
                        .Select(uc => new
                        {
                            uc.UserId,
                            uc.User.FullName,
                            uc.User.ProfilePicture
                        }).ToList()
                    }).ToListAsync();
                if (!chats.Any())
                {
                    return Response<IEnumerable<DispatcherChatDTO>>.Success(new List<DispatcherChatDTO>(), "لا يوجد محادثات خدمة عملاء", 201);

                }

                var chatsDto = chats.Select(c => new DispatcherChatDTO
                {
                    Id = c.Id,
                    IsOpen = c.IsOpen,
                    ClientId = c.UserChats.Select(uc=>uc.UserId).FirstOrDefault()!,
                    ClientName = c.UserChats.Select(uc=>uc.FullName).FirstOrDefault()!,
                    ProfilePicture = c.UserChats.Select(uc => uc.ProfilePicture).FirstOrDefault() ?? string.Empty
                });
                return Response<IEnumerable<DispatcherChatDTO>>.Success(chatsDto, "تم جلب المحادثات", 200);
            }
            catch (Exception ex)
            {
                return Response<IEnumerable<DispatcherChatDTO>>.Failure($"حدث خطأ اثناء جلب المحادثات", 500);
            }
        }

        public async Task<Response<ChatDTO>> GetByIdAsync(string chatId)
        {
            try
            {
                var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
                if(chat == null)
                {
                    return Response<ChatDTO>.Failure("المحادثة غير موجودة", 404);
                }

                return Response<ChatDTO>.Success(new ChatDTO
                {
                    Id = chat.Id,
                    Type = chat.Type,
                    IsOpen = chat.IsOpen,
                    CreatedAt = chat.CreatedAt
                }, "تم جلب المحادثة", 200);
            }
            catch (Exception ex)
            {
                return Response<ChatDTO>.Failure($"حدث خطأ اثناء جلب المحادثات", 500);
            }
        }

        public async Task<Response<Chat>> CreateSupportChatAsync(string clientId)
        {
            try
            {
                var client = await _userManager.FindByIdAsync(clientId);
                if (client == null)
                {
                    return Response<Chat>.Failure("العميل غير موجود.", 404);
                }

                var isExistedClientChat = _context.Chats.Include(c=>c.UserChats)
                    .Any(c => c.Type == ChatType.SupportChat && c.IsOpen
                    && c.UserChats.Any(uc => uc.Role == "Client" && uc.UserId == clientId));
                if (isExistedClientChat)
                {
                    return Response<Chat>.Failure("توجد للعميل محادثة خدمة عملاء مفتوحة بالفعل", 400);
                }

                var chat = new Chat
                {
                    Id= Guid.NewGuid().ToString(),
                    Type = ChatType.SupportChat,
                };
                await _unitOfWork.Chats.AddAsync(chat);
                _logger.LogInformation("Chat with Id {ChatId} is added", chat.Id);

                var dispatcherId = await _dispatcherService.GetAvailableDispatcherId();
                // update dispatcher LastHandledChatAt
                var dispatcher = await _userManager.FindByIdAsync(dispatcherId);
                dispatcher!.LastHandledChatAt = DateTime.Now.ToEgyptTime();
                var cachedDispatcher = _cacheService.GetData<DispatcherDTO>($"Dispatcher_{dispatcherId}");
                if (cachedDispatcher != null)
                {
                    cachedDispatcher.LastHandledChatAt = DateTime.Now.ToEgyptTime();
                    _cacheService.SetData($"Dispatcher_{dispatcher.Id}", cachedDispatcher);
                }

                var userChats = new List<UserChat>
                {
                    new UserChat
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId=client.Id,
                        Role="Client",
                        ChatId=chat.Id,
                    },
                    new UserChat
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId=dispatcherId,
                        Role="Dispatcher",
                        ChatId=chat.Id,
                    }
                };
                await _unitOfWork.UserChats.AddRangeAsync(userChats);
                await _unitOfWork.SaveAsync();
                _logger.LogInformation("UserChats for client {ClientId} and dispatcher {DispatcherId} are added", clientId, dispatcherId);

                _logger.LogInformation("Support Chat is created successfully");
                return Response<Chat>.Success(chat, "تم إنشاء المحادثة.", 200);
            }
            catch (Exception ex)
            {
                return Response<Chat>.Failure($"حدث خطأ اثناء انشاء المحادثة", 500);
            }
        }

        public async Task<Response<string>> CreateTripChat(string senderId,string reciverId,string tripId)
        {
            try
            {
                var sender = await _userManager.FindByIdAsync(senderId);
                var reciver = await _userManager.FindByIdAsync(reciverId);
                if (sender == null || reciver == null)
                {
                    return Response<string>.Failure("المستخدم غير موجود.", 404);
                }
                if (_context.Chats.Any(c => c.Type == ChatType.TripChat && c.IsOpen
                    && c.UserChats.Any(uc => uc.UserId == senderId && uc.UserId == reciverId && c.TripId == tripId)))
                {
                    return Response<string>.Failure("توجد محادثة مفتوحة بالفعل بين المستخدمين لهذه الرحلة.", 400);
                }
                var chat = new Chat
                {
                    Id = Guid.NewGuid().ToString(),
                    Type = ChatType.TripChat,
                    TripId = tripId,
                    IsOpen = true
                };
                await _unitOfWork.Chats.AddAsync(chat);

                var senderRoles = await _userManager.GetRolesAsync(sender);
                var reciverRoles = await _userManager.GetRolesAsync(reciver);

                var userChats = new List<UserChat>
                {
                    new UserChat
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId=sender.Id,
                        Role=senderRoles.FirstOrDefault(),
                        ChatId=chat.Id,
                    },
                    new UserChat
                    {
                        Id = Guid.NewGuid().ToString(),
                        UserId=reciver.Id,
                        Role=reciverRoles.FirstOrDefault(),
                        ChatId=chat.Id,
                    }
                };
                await _unitOfWork.UserChats.AddRangeAsync(userChats);
                await _unitOfWork.SaveAsync();
                return Response<string>.Success(chat.Id, "تم إنشاء محادثة الرحلة بنجاح.", 201);
            }
            catch (Exception ex)
            {
                return Response<string>.Failure($"حدث خطأ اثناء انشاء محادثة الرحلة", 500);
            }
        }

        public async Task<Response<ChatDTO>> GetTripChat(string tripId, string senderId, string reciverId)
        {
            try
            {
                var chat = await _context.Chats
                    .Include(c => c.UserChats)
                    .FirstOrDefaultAsync(c => c.Type == ChatType.TripChat && c.IsOpen && c.TripId == tripId
                    && c.UserChats.Any(uc => uc.UserId == senderId || uc.UserId == reciverId));

                if (chat == null)
                {
                    return Response<ChatDTO>.Failure("لا توجد محادثة لهذه الرحلة بين المستخدمين.", 404);
                }
                return Response<ChatDTO>.Success(new ChatDTO
                {
                    Id = chat.Id,
                    Type = chat.Type,
                    IsOpen = chat.IsOpen,
                    CreatedAt = chat.CreatedAt


                }, "تم جلب المحادثة بنجاح.", 200);

            }
            catch (Exception ex)
            {
                return Response<ChatDTO>.Failure($"حدث خطأ اثناء جلب المحادثة", 500);
            }
        }

        public async Task<Response<ChatClosingDTO>> CloseChatAsync(string chatId)
        {
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var chat = await _context.Chats.Include(c => c.UserChats)
                    .ThenInclude(uc=>uc.User)
                    .FirstOrDefaultAsync(c => c.Id == chatId);
                if (chat == null)
                {
                    return Response<ChatClosingDTO>.Failure("المحادثة غير موجودة.", 404);
                }
                chat.IsOpen = false;
                var dispatcher=chat.UserChats.Where(uc => uc.Role == "Dispatcher")
                    .Select(uc=>uc.User).FirstOrDefault();
                dispatcher!.LastHandledChatAt= DateTime.Now.ToEgyptTime();
                var chatClosingDTO = new ChatClosingDTO
                {
                    User1Id= chat.UserChats.FirstOrDefault(uc => uc.Role == "Client")?.UserId!,
                    User2Id = dispatcher.Id,
                };

                var cachedDispatcher = _cacheService.GetData<DispatcherDTO>($"Dispatcher_{dispatcher.Id}");
                if (cachedDispatcher != null)
                {
                    cachedDispatcher.LastHandledChatAt = DateTime.Now.ToEgyptTime();
                    _cacheService.SetData($"Dispatcher_{dispatcher.Id}", cachedDispatcher);
                }

                await _unitOfWork.Chats.UpdateAsync(chat);
                await _unitOfWork.SaveAsync();

                await transaction.CommitAsync();
                return Response<ChatClosingDTO>.Success(chatClosingDTO, "تم إغلاق المحادثة بنجاح.", 200);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return Response<ChatClosingDTO>.Failure($"حدث خطأ اثناء إغلاق المحادثة", 500);
            }
        }

        public async Task HandleUnClosedChats(CancellationToken cancellationToken = default)
        {
            const int batchSize = 100;
            var threshold = DateTime.Now.ToEgyptTime().AddHours(-24);
            int skip = 0;
            List<Chat> batch;

            do
            {
                batch = await _context.Chats
                    .Where(c => c.IsOpen && c.Type == ChatType.SupportChat)
                    .OrderBy(c => c.Id)
                    .Skip(skip)
                    .Take(batchSize)
                    .ToListAsync(cancellationToken);

                var chatIds = batch.Select(c => c.Id).ToList();

                var latestMessages = await _context.Messages
                    .Where(m => chatIds.Contains(m.ChatId))
                    .GroupBy(m => m.ChatId)
                    .Select(g => new { ChatId = g.Key, LastMessageAt = g.Max(m => m.SendAt) })
                    .ToListAsync(cancellationToken);

                var chatsToClose = batch
                    .Join(latestMessages,
                          chat => chat.Id,
                          msg => msg.ChatId,
                          (chat, msg) => new { Chat = chat, LastMessageAt = msg.LastMessageAt })
                    .Where(x => x.LastMessageAt <= threshold)
                    .Select(x => x.Chat)
                    .ToList();
                
                foreach (var chat in chatsToClose)
                {
                    chat.IsOpen = false;
                }

                await _context.SaveChangesAsync(cancellationToken);
                skip += batchSize;
            }
            while (batch.Count == batchSize && !cancellationToken.IsCancellationRequested);
        }
    }
}
