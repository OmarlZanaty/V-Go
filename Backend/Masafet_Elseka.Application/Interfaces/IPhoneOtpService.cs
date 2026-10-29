using Masafet_Elseka.Application.DTOs.Collection;
using Masafet_Elseka.Application.Response;

namespace Masafet_Elseka.Application.Interfaces
{
    public interface IPhoneOtpService
    {
        Task<Response<object>> RequestAsync(string? phone);
        Task<Response<object>> VerifyAsync(string? phone, string? code);
        Task<Response<string>> ResetPasswordAsync(string resetToken, string? newPassword);
        Task<List<SmsOutboxMessageDTO>> ClaimOutboxAsync(Guid deviceId, int max);
        Task<Response<string>> ReportDeliveryAsync(Guid deviceId, Guid id, SmsDeliveryDTO dto);
        Task<List<SmsOutboxAdminDTO>> GetOutboxAsync(int take);
        Task<Response<string>> ReportOutboxAsync(Guid deviceId, Guid id, SmsOutboxResultDTO result);
    }
}
