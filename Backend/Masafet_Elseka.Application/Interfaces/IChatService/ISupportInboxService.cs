using Masafet_Elseka.Application.Response;

namespace Masafet_Elseka.Application.Interfaces.IChatService
{
    // The dashboard «الدعم» inbox: every rider/captain support chat, answered by
    // any Admin or Dispatcher.
    public interface ISupportInboxService
    {
        Task<SupportChatPageDTO> ListAsync(string status, string? search, int page, int pageSize, CancellationToken ct = default);
        Task<Response<List<SupportMessageDTO>>> MessagesAsync(string chatId, int skip, int take, CancellationToken ct = default);
        Task<Response<SupportMessageDTO>> ReplyAsync(string chatId, string staffUserId, string content, CancellationToken ct = default);
        Task<Response<string>> SetOpenAsync(string chatId, bool open, CancellationToken ct = default);
        Task<int> UnreadCountAsync(CancellationToken ct = default);
    }

    public class SupportChatRowDTO
    {
        public string ChatId { get; set; } = string.Empty;
        public string UserId { get; set; } = string.Empty;
        public string? UserName { get; set; }
        public string? UserPhone { get; set; }
        public string UserRole { get; set; } = "Client"; // Client | Driver
        public bool IsOpen { get; set; }
        public DateTime CreatedAt { get; set; }
        public string? LastMessage { get; set; }
        public DateTime? LastMessageAt { get; set; }
        public bool LastMessageFromUser { get; set; }
        public int UnreadCount { get; set; }
    }

    public class SupportChatPageDTO
    {
        public List<SupportChatRowDTO> Data { get; set; } = new();
        public int TotalCount { get; set; }
    }

    public class SupportMessageDTO
    {
        public string Id { get; set; } = string.Empty;
        public string ChatId { get; set; } = string.Empty;
        public string SenderId { get; set; } = string.Empty;
        public string? SenderName { get; set; }
        public bool FromStaff { get; set; }
        public string Content { get; set; } = string.Empty;
        public DateTime SentAt { get; set; }
    }
}
