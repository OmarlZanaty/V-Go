using Masafet_Elseka.Application.Common;
using Masafet_Elseka.Application.DTOs;
using Masafet_Elseka.Application.ExternalDTOs.OTP;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Domain.ExternalInterfaces;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Common
{
    public class OTP
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly IMailService _mailService;
        private readonly ICacheService _cacheService;
        public OTP(IHttpContextAccessor httpContextAccessor, IMailService mailService, ICacheService cacheService)
        {
            _httpContextAccessor = httpContextAccessor;
            _mailService = mailService;
            _cacheService=cacheService;

        }

        public bool IsOtpValid(string key)
        {
            var combinedValue = _httpContextAccessor.HttpContext.Request.Cookies[key];

            if (string.IsNullOrEmpty(combinedValue))
            {
                return false;
            }

            var parts = combinedValue.Split('|');

            if (parts.Length < 2 || parts.Length > 3)
            {
                return false;
            }

            var otp = parts[0];
            var expirationTime = parts[1];

            string email = parts.Length == 3 ? parts[2] : string.Empty;

            if (!DateTime.TryParse(expirationTime, out var expiryDateTime))
            {
                return false;
            }

            if (DateTime.Now.ToEgyptTime() > expiryDateTime)
            {
                return false;
            }

            return true;
        }


        public async Task<Response<bool>> SendRegisterationOTPAsync(string email)
        {
            var otp = GenerateOTP.Generateotp();
            var expiration = DateTime.Now.ToEgyptTime().AddMinutes(10);

            var otpData = new OtpCacheModel
            {
                Otp = otp,
                Email = email,
                ExpirationTime = expiration
            };

            _cacheService.SetData($"OTP_Register_{email}", otpData, TimeSpan.FromMinutes(10));

            var data = _cacheService.GetData<OtpCacheModel>($"OTP_Register_{email}");
            //Console.WriteLine($"OTP: {data.Otp}, Email: {data.Email}, Expires At: {data.ExpirationTime}");

            MailRequestDTO mail = new()
            {
                Email = email,
                Subject = "Verification OTP - V.GO",
                Body = $@"
                <html dir='rtl' lang='ar'>
                  <body style='margin: 0; padding: 0; background-color: #f2f2f2; font-family: 'Cairo', Arial, sans-serif;'>
                    <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='background-color: #f2f2f2; padding: 40px 0;'>
                      <tr>
                        <td align='center'>
                          <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='600' style='background: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1);'>
                            <tr>
                              <td style='background-color: #030408; padding: 30px; text-align: center; color: white;'>
                                <img src='cid:vgo_logo' alt='V.GO Logo' style='width: 85px; height: auto; margin-bottom: 10px;' />
                                <p style='margin: 5px 0 0; font-size: 18px; color: #ffffff;'>رمز التحقق الخاص بك</p>
                              </td>
                            </tr>
                            <tr>
                              <td style='padding: 30px; text-align: right; color: #333333;'>
                                <p style='font-size: 16px;'>،عزيزي المستخدم</p>
                                <p style='font-size: 16px;'> :لإكمال عملية التسجيل، الرجاء استخدام رمز التحقق التالي</p>
                                <p style='font-size: 28px; font-weight: bold; color: #DDE01F; text-align: center; margin: 30px 0;'>{otp}</p>
                                <p style='font-size: 16px;'><strong>يرجى الانتباه:</strong></p>
                                <ul style='font-size: 15px; line-height: 1.8; padding: 0; margin: 10px 0; list-style: none; direction: rtl;'>
                                  <li style='display: flex; align-items: flex-start; margin-bottom: 8px;'>
                                    <span style='min-width: 10px; margin-left: 10px; color: #DDE01F;'>•</span>
                                    <span>الرمز صالح لمدة <strong>10 دقائق</strong> فقط.</span>
                                  </li>
                                  <li style='display: flex; align-items: flex-start; margin-bottom: 8px;'>
                                    <span style='min-width: 10px; margin-left: 10px; color: #DDE01F;'>•</span>
                                    <span>لا تشارك هذا الرمز مع أي شخص لضمان أمان حسابك.</span>
                                  </li>
                                </ul>
                                <p style='font-size: 16px;'>.إذا لم تطلب هذا الرمز، يمكنك تجاهل هذه الرسالة</p>
                                <p style='margin-top: 40px; font-size: 16px;'>،تحياتنا<br><strong style='color:#030408;'>V.GO فريق</strong></p>
                              </td>
                            </tr>
                            <tr>
                              <td style='background-color: #DDE01F; padding: 15px; text-align: center; font-size: 13px; color: #030408;'>
                                &copy; {DateTime.Now.Year} V.GO - جميع الحقوق محفوظة
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </body>
                </html>"
            };

            var response = await _mailService.SendEmailAsync(mail);
            return response;
        }

        public async Task<Response<bool>> SendResetPasswordOTPAsync(string email)
        {
            var otp = GenerateOTP.Generateotp();
            var expirationTime = DateTime.Now.ToEgyptTime().AddMinutes(10);

            var otpData = new OtpCacheModel
            {
                Otp = otp,
                Email = email,
                ExpirationTime = expirationTime
            };
            _cacheService.SetData($"OTP_ResetPassword_{email}", otpData, TimeSpan.FromMinutes(10));

            MailRequestDTO mail = new()
            {
                Email = email,
                Subject = "Reset Password OTP - V.GO",
                Body = $@"
                <html dir='rtl' lang='ar'>
                  <body style='margin: 0; padding: 0; background-color: #f2f2f2; font-family: 'Cairo', Arial, sans-serif;'>
                    <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='background-color: #f2f2f2; padding: 40px 0;'>
                      <tr>
                        <td align='center'>
                          <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='600' style='background: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1);'>
                            <tr>
                              <td style='background-color: #030408; padding: 30px; text-align: center; color: white;'>
                                <img src='cid:vgo_logo' alt='V.GO Logo' style='width: 85px; height: auto; margin-bottom: 10px;' />
                                <p style='margin: 5px 0 0; font-size: 18px; color: #ffffff;'>رمز التحقق لإعادة تعيين كلمة المرور</p>
                              </td>
                            </tr>
                            <tr>
                              <td style='padding: 30px; text-align: right; color: #333333;'>
                                <p style='font-size: 16px;'>،عزيزي المستخدم</p>
                                <p style='font-size: 16px;'>يمكنك استخدام رمز التحقق التالي <strong>لإعادة تعيين كلمة المرور الخاصة بك</strong>:</p>
                                <p style='font-size: 28px; font-weight: bold; color: #DDE01F; text-align: center; margin: 30px 0;'>{otp}</p>
                                <p style='font-size: 16px;'><strong>يرجى الانتباه:</strong></p>
                                <ul style='font-size: 15px; line-height: 1.8; padding: 0; margin: 10px 0; list-style: none; direction: rtl;'>
                                  <li style='display: flex; align-items: flex-start; margin-bottom: 8px;'>
                                    <span style='min-width: 10px; margin-left: 10px; color: #DDE01F;'>•</span>
                                    <span>الرمز صالح لمدة <strong>10 دقائق</strong> فقط.</span>
                                  </li>
                                  <li style='display: flex; align-items: flex-start; margin-bottom: 8px;'>
                                    <span style='min-width: 10px; margin-left: 10px; color: #DDE01F;'>•</span>
                                    <span>لا تشارك هذا الرمز مع أي شخص لضمان أمان حسابك.</span>
                                  </li>
                                </ul>
                                <p style='font-size: 16px;'>.إذا لم تطلب إعادة تعيين كلمة المرور، يمكنك تجاهل هذه الرسالة</p>
                                <p style='margin-top: 40px; font-size: 16px;'>،تحياتنا<br><strong style='color:#030408;'>V.GO فريق</strong></p>
                              </td>
                            </tr>
                            <tr>
                              <td style='background-color: #DDE01F; padding: 15px; text-align: center; font-size: 13px; color: #030408;'>
                                &copy; {DateTime.Now.Year} V.GO - جميع الحقوق محفوظة
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </body>
                </html>"
            };
            var response = await _mailService.SendEmailAsync(mail);
            return response;
        }
        public async Task<Response<bool>> ResendOtpAsync(string email, OtpType otpType)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(email))
                    return Response<bool>.Failure("البريد الإلكتروني غير صالح");

                var otp = GenerateOTP.Generateotp();
                var expirationTime = DateTime.Now.ToEgyptTime().AddMinutes(10);

                var otpData = new OtpCacheModel
                {
                    Otp = otp,
                    Email = email,
                    ExpirationTime = expirationTime
                };

                string cacheKey;
                string subject;
                string body;

                if (otpType == OtpType.Register)
                {
                    cacheKey = $"OTP_Register_{email}";
                    subject = "New Verification OTP - V.GO";
                    body = "لتأكيد التسجيل";
                }
                else
                {
                    cacheKey = $"OTP_ResetPassword_{email}";
                    subject = "New Reset Password OTP - V.GO";
                    body = "لإعادة تعيين كلمة المرور";
                }
                // Save to cache
                _cacheService.SetData(cacheKey, otpData, TimeSpan.FromMinutes(10));

                string message = $@"
                <html dir='rtl' lang='ar'>
                  <body style='margin: 0; padding: 0; background-color: #f2f2f2; font-family: 'Cairo', Arial, sans-serif;'>
                    <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='100%' style='background-color: #f2f2f2; padding: 40px 0;'>
                      <tr>
                        <td align='center'>
                          <table role='presentation' cellspacing='0' cellpadding='0' border='0' width='600' style='background: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.1);'>
                            <tr>
                              <td style='background-color: #030408; padding: 30px; text-align: center; color: white;'>
                                <img src='cid:vgo_logo' alt='V.GO Logo' style='width: 85px; height: auto; margin-bottom: 10px;' />
                                <p style='margin: 5px 0 0; font-size: 18px; color: #ffffff;'>رمز التحقق الجديد</p>
                              </td>
                            </tr>
                            <tr>
                              <td style='padding: 30px; text-align: right; color: #333333;'>
                                <p style='font-size: 16px;'>،عزيزي المستخدم</p>
                                <p style='font-size: 16px;'>يرجى استخدام رمز التحقق التالي <strong>{body}</strong>:</p>
                                <p style='font-size: 28px; font-weight: bold; color: #DDE01F; text-align: center; margin: 30px 0;'>{otp}</p>
                                <p style='font-size: 16px;'><strong>يرجى الانتباه:</strong></p>
                                <ul style='font-size: 15px; line-height: 1.8; padding: 0; margin: 10px 0; list-style: none; direction: rtl;'>
                                  <li style='display: flex; align-items: flex-start; margin-bottom: 8px;'>
                                    <span style='min-width: 10px; margin-left: 10px; color: #DDE01F;'>•</span>
                                    <span>الرمز صالح لمدة <strong>10 دقائق</strong> فقط.</span>
                                  </li>
                                  <li style='display: flex; align-items: flex-start; margin-bottom: 8px;'>
                                    <span style='min-width: 10px; margin-left: 10px; color: #DDE01F;'>•</span>
                                    <span>لا تشارك هذا الرمز مع أي شخص لضمان أمان حسابك.</span>
                                  </li>
                                </ul>
                                <p style='font-size: 16px;'>.إذا لم تطلب هذا الرمز، يمكنك تجاهل هذه الرسالة</p>
                                <p style='margin-top: 40px; font-size: 16px;'>،تحياتنا<br><strong style='color:#030408;'>V.GO فريق</strong></p>
                              </td>
                            </tr>
                            <tr>
                              <td style='background-color: #DDE01F; padding: 15px; text-align: center; font-size: 13px; color: #030408;'>
                                &copy; {DateTime.Now.Year} V.GO - جميع الحقوق محفوظة
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </body>
                </html>";

                var mailRequest = new MailRequestDTO
                {
                    Email = email,
                    Subject = subject,
                    Body = message
                };

                var result = await _mailService.SendEmailAsync(mailRequest);
                return result;
            }
            catch (Exception ex)
            {
                return Response<bool>.Failure($"حدث خطأ أثناء إعادة إرسال رمز التحقق: {ex.Message}");
            }
        }

    }
}
