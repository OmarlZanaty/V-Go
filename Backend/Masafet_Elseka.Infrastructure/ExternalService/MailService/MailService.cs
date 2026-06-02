using MailKit.Net.Smtp;
using MailKit.Security;
using Masafet_Elseka.Application.DTOs;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.ExternalInterfaces;
using Microsoft.Extensions.Options;
using MimeKit;
using System.Threading.Tasks;


namespace Masafet_Elseka.Infrastructure.ExternalService.MailService
{
    public class MailService : IMailService
    {
        private readonly MailSettingsDTO _mailSettings;

        public MailService(IOptions<MailSettingsDTO> mailSettings)
        {
            _mailSettings = mailSettings.Value;
        }
        public async Task<Response<bool>> SendEmailAsync(MailRequestDTO mailRequest)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(_mailSettings.Email) || !MailboxAddress.TryParse(_mailSettings.Email, out var sender))
                {
                    return Response<bool>.Failure("Invalid sender email configured.", 500);
                }

                var email = new MimeMessage
                {
                    Sender = MailboxAddress.Parse(_mailSettings.Email),
                    Subject = mailRequest.Subject
                };

                email.To.Add(MailboxAddress.Parse(mailRequest.Email));

                var builder = new BodyBuilder();

                var logoPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", "v-go-logo-2.png");
                if (File.Exists(logoPath))
                {
                    var image = builder.LinkedResources.Add(logoPath);
                    image.ContentId = "vgo_logo";
                }

                builder.HtmlBody = mailRequest.Body;

                if (mailRequest.Attachments != null && mailRequest.Attachments.Any())
                {
                    foreach (var attachment in mailRequest.Attachments)
                    {
                        if (attachment.Length > 0)
                        {
                            using var ms = new MemoryStream();
                            await attachment.CopyToAsync(ms);
                            builder.Attachments.Add(attachment.FileName, ms.ToArray(), MimeKit.ContentType.Parse(attachment.ContentType));
                        }
                    }
                }

                email.Body = builder.ToMessageBody();

                email.From.Add(new MailboxAddress(_mailSettings.DisplayName, _mailSettings.Email));

                using var smtp = new MailKit.Net.Smtp.SmtpClient
                {
                    CheckCertificateRevocation = false
                };

                await smtp.ConnectAsync(_mailSettings.Host, _mailSettings.Port, SecureSocketOptions.StartTls);
                await smtp.AuthenticateAsync(_mailSettings.Email, _mailSettings.Password);
                await smtp.SendAsync(email);
                await smtp.DisconnectAsync(true);

                return Response<bool>.Success(true, "Email sent successfully.");
            }
            catch (System.Net.Mail.SmtpException smtpEx)
            {
                return Response<bool>.Failure(
                    "An error occurred while sending the email. Please try again later.",
                    500,
                    new List<string> { smtpEx.Message }
                );
            }
            catch (Exception ex)
            {
                return Response<bool>.Failure(
                    "An unexpected error occurred while sending the email. Please try again later.",
                    500,
                    new List<string> { ex.Message }
                );
            }
        }
    }
}
