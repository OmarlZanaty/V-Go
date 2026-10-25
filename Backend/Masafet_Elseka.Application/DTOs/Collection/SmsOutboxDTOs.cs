namespace Masafet_Elseka.Application.DTOs.Collection
{
    public class SmsOutboxMessageDTO
    {
        public Guid Id { get; set; }
        public string To { get; set; } = string.Empty;
        public string Body { get; set; } = string.Empty;
    }

    public class SmsOutboxResultDTO
    {
        public bool Sent { get; set; }
        public string? Error { get; set; }
    }
}
