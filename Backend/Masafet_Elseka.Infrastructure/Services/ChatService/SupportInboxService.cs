using Masafet_Elseka.Application.DTOs.Message;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Application.Interfaces.IChatService;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Masafet_Elseka.Infrastructure.Services.ChatService
{
    public class SupportInboxService : ISupportInboxService
    {
        private readonly Context _context;
        private readonly INotificationService _notifications;
        private readonly IHubContext<SupportChatHub> _hub;
        private readonly ILogger<SupportInboxService> _logger;

        public SupportInboxService(Context context, INotificationService notifications,
            IHubContext<SupportChatHub> hub, ILogger<SupportInboxService> logger)
        {
            _context = context;
            _notifications = notifications;
            _hub = hub;
            _logger = logger;
        }

        // The rider/captain who opened the chat is its "Client" participant.
        private const string UserRole = "Client";

        private async Task<HashSet<string>> StaffIdsAsync(CancellationToken ct) =>
            (await (from ur in _context.UserRoles
                    join r in _context.Roles on ur.RoleId equals r.Id
                    where r.Name == "Admin" || r.Name == "Dispatcher"
                    select ur.UserId).ToListAsync(ct)).ToHashSet();

        public async Task<SupportChatPageDTO> ListAsync(string status, string? search, int page, int pageSize, CancellationToken ct = default)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var chats = _context.Chats.AsNoTracking().Where(c => c.Type == ChatType.SupportChat);
            if (status == "open") chats = chats.Where(c => c.IsOpen);
            else if (status == "closed") chats = chats.Where(c => !c.IsOpen);

            var rows = await chats
                .Select(c => new
                {
                    c.Id,
                    c.IsOpen,
                    c.CreatedAt,
                    User = c.UserChats.Where(uc => uc.Role == UserRole).Select(uc => uc.User).FirstOrDefault(),
                    Last = c.Messages.OrderByDescending(m => m.SendAt).Select(m => new { m.Content, m.SendAt, m.UserId }).FirstOrDefault(),
                })
                .ToListAsync(ct);

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim();
                rows = rows.Where(r => r.User != null &&
                    ((r.User.FullName ?? "").Contains(s, StringComparison.OrdinalIgnoreCase) ||
                     (r.User.PhoneNumber ?? "").Contains(s))).ToList();
            }

            var ordered = rows.OrderByDescending(r => r.Last?.SendAt ?? r.CreatedAt).ToList();
            var pageRows = ordered.Skip((page - 1) * pageSize).Take(pageSize).ToList();

            var ids = pageRows.Select(r => r.Id).ToList();
            var userIds = pageRows.Where(r => r.User != null).Select(r => r.User!.Id).ToList();
            var drivers = (await (from ur in _context.UserRoles
                                  join r in _context.Roles on ur.RoleId equals r.Id
                                  where r.Name == "Driver" && userIds.Contains(ur.UserId)
                                  select ur.UserId).ToListAsync(ct)).ToHashSet();
            var messages = await _context.Messages.AsNoTracking()
                .Where(m => ids.Contains(m.ChatId))
                .Select(m => new { m.ChatId, m.UserId, m.SendAt })
                .ToListAsync(ct);

            var data = pageRows.Select(r =>
            {
                var uid = r.User?.Id ?? string.Empty;
                var mine = messages.Where(m => m.ChatId == r.Id).ToList();
                var lastStaff = mine.Where(m => m.UserId != uid).Select(m => (DateTime?)m.SendAt).DefaultIfEmpty().Max();
                return new SupportChatRowDTO
                {
                    ChatId = r.Id,
                    UserId = uid,
                    UserName = r.User?.FullName,
                    UserPhone = r.User?.PhoneNumber,
                    UserRole = drivers.Contains(uid) ? "Driver" : "Client",
                    IsOpen = r.IsOpen,
                    CreatedAt = r.CreatedAt,
                    LastMessage = r.Last?.Content,
                    LastMessageAt = r.Last?.SendAt,
                    LastMessageFromUser = r.Last != null && r.Last.UserId == uid,
                    // Messages from the user since the last staff reply.
                    UnreadCount = mine.Count(m => m.UserId == uid && (lastStaff == null || m.SendAt > lastStaff)),
                };
            }).ToList();

            return new SupportChatPageDTO { Data = data, TotalCount = ordered.Count };
        }

        public async Task<Response<List<SupportMessageDTO>>> MessagesAsync(string chatId, int skip, int take, CancellationToken ct = default)
        {
            var chat = await _context.Chats.AsNoTracking()
                .Include(c => c.UserChats)
                .FirstOrDefaultAsync(c => c.Id == chatId && c.Type == ChatType.SupportChat, ct);
            if (chat == null) return Response<List<SupportMessageDTO>>.Failure("المحادثة مش موجودة", 404);
            var userId = chat.UserChats.FirstOrDefault(uc => uc.Role == UserRole)?.UserId;

            var list = await _context.Messages.AsNoTracking()
                .Where(m => m.ChatId == chatId)
                .OrderBy(m => m.SendAt)
                .Skip(Math.Max(0, skip)).Take(Math.Clamp(take, 1, 500))
                .Select(m => new SupportMessageDTO
                {
                    Id = m.Id,
                    ChatId = m.ChatId,
                    SenderId = m.UserId,
                    SenderName = m.User.FullName,
                    FromStaff = m.UserId != userId,
                    Content = m.Content,
                    SentAt = m.SendAt,
                })
                .ToListAsync(ct);
            return Response<List<SupportMessageDTO>>.Success(list, "", 200);
        }

        public async Task<Response<SupportMessageDTO>> ReplyAsync(string chatId, string staffUserId, string content, CancellationToken ct = default)
        {
            content = (content ?? string.Empty).Trim();
            if (content.Length == 0) return Response<SupportMessageDTO>.Failure("اكتب الرد", 400);

            var chat = await _context.Chats
                .Include(c => c.UserChats)
                .FirstOrDefaultAsync(c => c.Id == chatId && c.Type == ChatType.SupportChat, ct);
            if (chat == null) return Response<SupportMessageDTO>.Failure("المحادثة مش موجودة", 404);
            var userId = chat.UserChats.FirstOrDefault(uc => uc.Role == UserRole)?.UserId;
            if (string.IsNullOrEmpty(userId)) return Response<SupportMessageDTO>.Failure("صاحب المحادثة مش موجود", 404);

            // The replying staff member joins the chat so the apps' existing message
            // endpoints keep working for both sides.
            if (!chat.UserChats.Any(uc => uc.UserId == staffUserId))
            {
                _context.UserChats.Add(new UserChat
                {
                    Id = Guid.NewGuid().ToString(),
                    UserId = staffUserId,
                    Role = "Dispatcher",
                    ChatId = chat.Id,
                });
            }
            chat.IsOpen = true;

            var message = new Message
            {
                Id = Guid.NewGuid().ToString(),
                ChatId = chat.Id,
                UserId = staffUserId,
                Content = content,
                SendAt = DateTime.Now.ToEgyptTime(),
            };
            _context.Messages.Add(message);
            await _context.SaveChangesAsync(ct);

            var staffName = await _context.Users.Where(u => u.Id == staffUserId).Select(u => u.FullName).FirstOrDefaultAsync(ct);
            var appMessage = new MessageDTO
            {
                Id = message.Id,
                SenderId = staffUserId,
                ReceiverId = userId,
                ChatId = chat.Id,
                Content = content,
                SendAt = message.SendAt,
            };
            try
            {
                // Live in the rider / captain app, and on the other dashboards.
                await _hub.Clients.User(userId).SendAsync("ReceiveSupportMessage", appMessage, ct);
                await _hub.Clients.Group(SupportChatHub.StaffGroup).SendAsync("ReceiveSupportMessage", appMessage, ct);
            }
            catch (Exception ex) { _logger.LogWarning(ex, "Support reply live push failed"); }
            try
            {
                var preview = content.Length > 100 ? content[..100] + "…" : content;
                await _notifications.SendNotificationToUserAsync(userId, "رد من خدمة العملاء", preview,
                    new Dictionary<string, string> { ["type"] = "support", ["chatId"] = chat.Id }, ct);
            }
            catch (Exception ex) { _logger.LogWarning(ex, "Support reply push notification failed"); }

            return Response<SupportMessageDTO>.Success(new SupportMessageDTO
            {
                Id = message.Id,
                ChatId = chat.Id,
                SenderId = staffUserId,
                SenderName = staffName,
                FromStaff = true,
                Content = content,
                SentAt = message.SendAt,
            }, "تم إرسال الرد", 200);
        }

        public async Task<Response<string>> SetOpenAsync(string chatId, bool open, CancellationToken ct = default)
        {
            var chat = await _context.Chats.FirstOrDefaultAsync(c => c.Id == chatId && c.Type == ChatType.SupportChat, ct);
            if (chat == null) return Response<string>.Failure("المحادثة مش موجودة", 404);
            if (open)
            {
                // A user has at most one open support chat.
                var userId = await _context.UserChats.Where(uc => uc.ChatId == chatId && uc.Role == UserRole)
                    .Select(uc => uc.UserId).FirstOrDefaultAsync(ct);
                var otherOpen = await _context.Chats.AnyAsync(c => c.Id != chatId && c.Type == ChatType.SupportChat && c.IsOpen
                    && c.UserChats.Any(uc => uc.Role == UserRole && uc.UserId == userId), ct);
                if (otherOpen) return Response<string>.Failure("العميل عنده محادثة مفتوحة تانية", 400);
            }
            chat.IsOpen = open;
            await _context.SaveChangesAsync(ct);
            return Response<string>.Success(chat.Id, open ? "تم فتح المحادثة" : "تم قفل المحادثة", 200);
        }

        public async Task<int> UnreadCountAsync(CancellationToken ct = default)
        {
            var page = await ListAsync("open", null, 1, 100, ct);
            return page.Data.Count(r => r.UnreadCount > 0);
        }
    }
}
