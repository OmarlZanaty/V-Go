using Masafet_Elseka.Application.DTOs;
using Masafet_Elseka.Application.DTOs.AuthDTOs;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Enums;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IAuthService
{
    public interface IAuthService
    {
        public Task<Response<string>> Register(RegisterDTO model);
        public Task<Response<LoginResponseDTO>> LoginAsync(LoginDTO model);
        public Task<Response<LoginResponseDTO>> LoginWithPhoneAsync(PhoneLoginDTO model);
        public Task<Response<LoginResponseDTO>> RegisterWithPhoneAsync(PhoneRegisterDTO model);
        public Task<Response<LoginResponseDTO>> LoginDriverWithPhoneAsync(PhoneLoginDTO model);
        public Task<Response<LoginResponseDTO>> RegisterDriverWithPhoneAsync(PhoneRegisterDriverDTO model);
        // Phone + password helpers: check if a phone is already registered (drives the
        // "set password" vs "enter password" branch), and reset a forgotten password
        // after an OTP check.
        public Task<Response<bool>> CheckPhoneExistsAsync(string phone);
        public Task<Response<string>> ResetPhonePasswordAsync(PhoneResetPasswordDTO model);
        // Google Sign-In (native token flow)
        public Task<Response<LoginResponseDTO>> GoogleTokenLoginAsync(GoogleTokenLoginDTO model);
        public Task<Response<LoginResponseDTO>> GoogleTokenDriverAsync(GoogleTokenDriverDTO model);
        public Task<Response<object>> LoginToDashboardAsync(LoginDTO model);
        public Task<Response<string>> ConfirmOtp(string otp, OtpType type, string email);
        public Task<Response<string>> LogoutAsync(string refreshToken);
        public Task<Response<string>> LogoutFromDashboardAsync();
        public Task<Response<string>> ChangePasswordAsync(ChangePasswordDTO model);
        public Task<Response<string>> ForgotPasswordAsync(string email);
        public Task<Response<bool>> ResendOtpAsync(string email, OtpType otpType);
        public Task<Response<string>> ResetPasswordAsync(ResetPasswordDTO model);
    }
}
