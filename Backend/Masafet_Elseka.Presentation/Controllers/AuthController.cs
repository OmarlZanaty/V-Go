using Masafet_Elseka.Application.DTOs;
using Masafet_Elseka.Application.DTOs.AuthDTOs;
using Masafet_Elseka.Application.ExternalInterfaces;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Interfaces.IAuthService;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.AuthState;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.GoogleAuthManagerService;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.GoogleAuthService;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.HTMLResponseService;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Serilog;
using System.ComponentModel.DataAnnotations;

namespace Masafet_Elseka.Presentation.Controllers
{

    [Route("api/[controller]")]
    [ApiController]
    [EnableRateLimiting("auth")]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;
        private readonly IJWTService _jWTService;
        private readonly ICacheService _cacheService;
        private readonly IConfiguration _configuration;
        private readonly IGoogleAuthService _googleAuthService;
        private readonly IGoogleAuthManager _googleAuthManager;
        private readonly IHtmlResponseService _htmlResponseService;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly RoleManager<IdentityRole> _roleManager;
        public AuthController(IAuthService authService, IJWTService jWTService, ICacheService cacheService,IGoogleAuthService googleAuthService,IConfiguration configuration, IGoogleAuthManager googleAuthManager, IHtmlResponseService htmlResponseService, UserManager<ApplicationUser> userManager, RoleManager<IdentityRole> roleManager)
        {
            _authService = authService;
            _jWTService = jWTService;
            _cacheService = cacheService;
            _googleAuthService = googleAuthService;
            _configuration = configuration;
            _googleAuthManager = googleAuthManager;
            _htmlResponseService = htmlResponseService;
            _userManager = userManager;
            _roleManager = roleManager;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromForm] RegisterDTO model)
        {
            if (model == null)
            {
                return BadRequest("نموذج البيانات غير صالح"); 
            }

            var result = await _authService.Register(model);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { message = result.Message , errors = result.Errors });
            }

            return StatusCode(result.StatusCode, new { message = result.Message, errors = result.Errors });
        }

        [HttpPost("confirmOtp")]
        public async Task<IActionResult> ConfirmOtp([FromQuery] string otp, OtpType type, [FromQuery] string email)
        {
            if (string.IsNullOrEmpty(otp) || string.IsNullOrEmpty(email))
            {
                return BadRequest("برجاء ادخال بيانات صالحة");
            }

            var result = await _authService.ConfirmOtp(otp, type, email);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { message = result.Message });
            }

            return StatusCode(result.StatusCode, new { message = result.Message });
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginDTO model)
        {
            if (model == null)
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.LoginAsync(model);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { data = result.Data, message = result.Message });
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("phone-login")]
        public async Task<IActionResult> PhoneLogin([FromBody] PhoneLoginDTO model)
        {
            if (model == null)
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.LoginWithPhoneAsync(model);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { data = result.Data, message = result.Message });
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("phone-register")]
        public async Task<IActionResult> PhoneRegister([FromBody] PhoneRegisterDTO model)
        {
            if (model == null)
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.RegisterWithPhoneAsync(model);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { data = result.Data, message = result.Message });
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("phone-login-driver")]
        public async Task<IActionResult> PhoneLoginDriver([FromBody] PhoneLoginDTO model)
        {
            if (model == null)
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.LoginDriverWithPhoneAsync(model);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { data = result.Data, message = result.Message });
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("phone-register-driver")]
        public async Task<IActionResult> PhoneRegisterDriver([FromBody] PhoneRegisterDriverDTO model)
        {
            if (model == null)
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.RegisterDriverWithPhoneAsync(model);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { data = result.Data, message = result.Message });
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        // Phone-first sign-in: the app calls this after the phone field to decide
        // between "set password" (new) and "enter password" (returning).
        [HttpGet("phone-exists")]
        public async Task<IActionResult> PhoneExists([FromQuery] string phone)
        {
            var result = await _authService.CheckPhoneExistsAsync(phone);
            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { exists = result.Data, message = result.Message });
            }
            return StatusCode(result.StatusCode, result.Message);
        }

        // Forgot password for phone accounts (OTP kept only for this path).
        [HttpPost("phone-reset-password")]
        public async Task<IActionResult> PhoneResetPassword([FromBody] PhoneResetPasswordDTO model)
        {
            if (model == null)
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.ResetPhonePasswordAsync(model);
            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { message = result.Message });
            }
            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("newrefreshtoken")]
        public async Task<IActionResult> NewRefreshToken(string token)
        {
            if (string.IsNullOrEmpty(token))
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _jWTService.GetNewRefreshToken(token);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, result.Data);
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("logout")]
        public async Task<IActionResult> Logout([FromHeader] string refreshToken)
        {
            var result = await _authService.LogoutAsync(refreshToken);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, result.Message);
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("changePassword")]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDTO model)
        {
            if (model == null)
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.ChangePasswordAsync(model);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, result.Message);
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("forgotPassword")]
        public async Task<IActionResult> ForgotPassword([FromBody,EmailAddress] string email)
        {
            if (string.IsNullOrEmpty(email))
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.ForgotPasswordAsync(email);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, result.Message);
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("resetPassword")]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordDTO model)
        {
            if (model==null)
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.ResetPasswordAsync(model);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, result.Message);
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("resendotp")]
        public async Task<IActionResult> ResendOtp([FromBody, EmailAddress] string email,OtpType otpType)
        {
            if (string.IsNullOrEmpty(email))
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.ResendOtpAsync(email,otpType);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { message= result.Message });
            }

            return StatusCode(result.StatusCode, new { message= result.Message });
        }

        [HttpPost("dashboardLogin")]
        public async Task<IActionResult> LoginToDashboardAsync([FromBody] LoginDTO model)
        {
            if (model == null)
            {
                return BadRequest("نموذج البيانات غير صالح");
            }

            var result = await _authService.LoginToDashboardAsync(model);

            if (result.IsSuccess)
            {
                return StatusCode(result.StatusCode, new { data = result.Data, message = result.Message });
            }

            return StatusCode(result.StatusCode, result.Message);
        }

        [HttpPost("dashboardLogout")]
        public async Task<IActionResult> LogoutFromDashboard()
        {
            var result = await _authService.LogoutFromDashboardAsync();
            return StatusCode(result.StatusCode, result.Message);
        }

        // Bootstrap endpoint — creates the first Admin account.
        // Automatically disabled once any Admin exists.
        [HttpPost("seed-admin")]
        [AllowAnonymous]
        public async Task<IActionResult> SeedAdmin([FromBody] LoginDTO model)
        {
            // Ensure "Admin" role exists
            if (!await _roleManager.RoleExistsAsync("Admin"))
                await _roleManager.CreateAsync(new IdentityRole("Admin"));

            var existingAdmins = await _userManager.GetUsersInRoleAsync("Admin");
            if (existingAdmins.Any())
                return BadRequest(new { message = "Admin account already exists." });

            var user = new ApplicationUser
            {
                UserName = model.Email,
                Email = model.Email,
                FullName = "Admin",
                Gender = "Male",
                EmailConfirmed = true,
                PhoneNumber = "+20100000000",
            };
            // Check if user already exists (e.g. created in a previous failed attempt)
            var existingUser = await _userManager.FindByEmailAsync(model.Email);
            if (existingUser != null)
            {
                if (!await _userManager.IsInRoleAsync(existingUser, "Admin"))
                    await _userManager.AddToRoleAsync(existingUser, "Admin");
                return Ok(new { message = "Admin role assigned.", email = model.Email });
            }

            var createResult = await _userManager.CreateAsync(user, model.Password);
            if (!createResult.Succeeded)
                return BadRequest(new { errors = createResult.Errors.Select(e => e.Description) });

            await _userManager.AddToRoleAsync(user, "Admin");
            return Ok(new { message = "Admin created successfully.", email = model.Email });
        }

        #region Google Web Auth

        [HttpGet("google-login")]
        public async Task<IActionResult> GoogleLogin()
        {
            try
            {
                var googleAuthUrl = await _googleAuthService.GetGoogleAuthUrl_Web();
                return Ok(new
                {
                    authUrl = googleAuthUrl,
                });
            }
            catch (Exception ex)
            {
                Log.Error(ex, "GoogleLogin error");
                return StatusCode(500, new { message = "حدث خطأ في الخادم. يرجى المحاولة لاحقًا." });
            }
        }

        [HttpPost("google-callback")]
        public async Task<IActionResult> GoogleCallback([FromBody] GoogleCallbackRequest request)
        {
            try
            {
                if (string.IsNullOrEmpty(request.Code))
                {
                    return BadRequest(new { message = "Invalid Google code" });
                }
                string idToken = await _googleAuthService.ExchangeCodeForTokenAsync(request.Code);

                if (string.IsNullOrEmpty(idToken))
                {
                    return BadRequest(new { message = "Failed to get token from Google" });
                }
                var result = await _googleAuthService.GoogleLogin(idToken);

                if (!result.IsSuccess)
                {
                    return BadRequest(new { message = result.Message });
                }
                return Ok(new
                {
                    message = "Login successful",
                    user = result.Data,
                    token = result.Data.Token,
                    refreshToken = result.Data.RefreshToken
                });
            }
            catch (Exception ex)
            {
                Log.Error(ex, "GoogleCallback error");
                return StatusCode(500, new { message = "حدث خطأ في الخادم. يرجى المحاولة لاحقًا." });
            }
        } 
        #endregion

        #region Google Mobile Auth
        [HttpGet("mobile/google-login")]
        public async Task<IActionResult> MobileGoogleLogin()
        {
            var result = await _googleAuthManager.GenerateMobileAuthUrlAsync();

            if (result.Success)
            {
                return Ok(result);
            }

            return BadRequest(result);
        }

        [HttpGet("mobile/callback")]
        public async Task<ContentResult> MobileCallback([FromQuery] string code, [FromQuery] string state)
        {
            var result = await _googleAuthManager.ProcessMobileCallbackAsync(code, state);

            switch (result.Status)
            {
                case "invalid":
                    return _htmlResponseService.GenerateInvalidStateHtml();

                case "completed":
                    var completedState = await _googleAuthManager.CheckAuthStatusAsync(state);
                    var userName = completedState.User?.GetType().GetProperty("name")?.GetValue(completedState.User)?.ToString() ?? "User";
                    return _htmlResponseService.GenerateSuccessHtml(userName);

                case "failed":
                default:
                    return _htmlResponseService.GenerateErrorHtml("Login Failed", result.Message);
            }
        }

        [HttpGet("mobile/check-auth/{state}")]
        public async Task<IActionResult> CheckAuthStatus(string state)
        {
            var result = await _googleAuthManager.CheckAuthStatusAsync(state);

            if (result.Success)
            {
                return Ok(result);
            }

            return BadRequest(result);
        } 
        #endregion

        #region Google Sign-In (native token)

        /// Rider: Google ID token → login or create Client account.
        [HttpPost("google-login-token")]
        public async Task<IActionResult> GoogleLoginToken([FromBody] GoogleTokenLoginDTO model)
        {
            var result = await _authService.GoogleTokenLoginAsync(model);
            return StatusCode(result.StatusCode, result.IsSuccess ? new { data = result.Data, message = result.Message } : (object)result.Message);
        }

        /// Captain: Google ID token → login existing driver or return isNewUser for signup.
        [HttpPost("google-login-driver-token")]
        public async Task<IActionResult> GoogleLoginDriverToken([FromBody] GoogleTokenDriverDTO model)
        {
            var result = await _authService.GoogleTokenDriverAsync(model);
            return StatusCode(result.StatusCode, result.IsSuccess ? new { data = result.Data, message = result.Message } : (object)result.Message);
        }

        #endregion
    }
}
