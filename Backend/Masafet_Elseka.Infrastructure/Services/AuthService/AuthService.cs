using CloudinaryDotNet.Actions;
using FluentValidation;
using Masafet_Elseka.Application.Common;
using Masafet_Elseka.Application.DTOs;
using Masafet_Elseka.Application.DTOs.AuthDTOs;
using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.ExternalDTOs.OTP;
using Masafet_Elseka.Application.ExternalInterfaces;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.ExternalInterfaces.ICloudinaryService;
using Masafet_Elseka.Application.Interfaces.IAuthService;
using Masafet_Elseka.Application.Interfaces.INotificationService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.ExternalService.UserCleanUpService;
using Masafet_Elseka.Infrastructure.Services.OnlineTrackerService;
using Masafet_Elseka.Infrastructure.UOW;
using Masafet_Elseka.Infrastructure.Validations;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Serilog;
using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.AuthService
{
    public class AuthService : IAuthService
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly RoleManager<IdentityRole> _roleManager;
        private readonly OTP _OTP;
        private readonly IJWTService _jwtService;
        private readonly ICacheService _cacheService;
        private readonly ICloudinaryService _cloudinaryService;
        private readonly IUnitOfWork _unitOfWork;
        private readonly Context _context;
        private readonly IUserCleanupService _userCleanup;
        private readonly INotificationService _notificationService;
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly OnlineTrackerService.OnlineTrackerService _onlineTrackerService;

        public AuthService(UserManager<ApplicationUser> userManager, RoleManager<IdentityRole> roleManager, OTP oTP, IJWTService jWTService,
            ICacheService cacheService, ICloudinaryService cloudinaryService, IUnitOfWork unitOfWork, Context context, IUserCleanupService userCleanup, IHttpContextAccessor httpContextAccessor, INotificationService notificationService, OnlineTrackerService.OnlineTrackerService onlineTrackerService)
        {
            _userManager = userManager;
            _roleManager = roleManager;
            _OTP = oTP;
            _jwtService = jWTService;
            _cacheService = cacheService;
            _cloudinaryService = cloudinaryService;
            _unitOfWork = unitOfWork;
            _context = context;
            _userCleanup = userCleanup;
            _httpContextAccessor = httpContextAccessor;
            _notificationService = notificationService;
            _onlineTrackerService = onlineTrackerService;
        }

        public async Task<Response<string>> Register(RegisterDTO model)
        {
            IDbContextTransaction transaction = null;

            try
            {
                var validator = new RegisterValidator().Validate(model);
                if (!validator.IsValid)
                {
                    var errors = validator.Errors.Select(e => e.ErrorMessage).ToList();
                    return Response<string>.Failure("البينات تحتوي على اخطاء يرجى مراجعتها", 400, errors);
                }


                var existingUserByEmail = await _userManager.FindByEmailAsync(model.Email);
                if (existingUserByEmail != null)
                {
                    return Response<string>.Failure("البريد الإلكتروني مستخدم من قبل أو لم يتم تأكيده، إذا لم يتم تأكيده حاول مرة اخرى بعد مرور 10 دقائق", 400);
                }

                var allowedRoles = new[] { "Client", "Dispatcher", "Accountant", "Driver" };
                if (!allowedRoles.Contains(model.Role))
                {
                    return Response<string>.Failure("الدور غير مسموح به", 400);
                }

                transaction = await _context.Database.BeginTransactionAsync();

                if (!await _roleManager.RoleExistsAsync(model.Role))
                {
                    var roleCreationResult = await _roleManager.CreateAsync(new IdentityRole(model.Role));
                    if (!roleCreationResult.Succeeded)
                    {
                        return Response<string>.Failure("فشل في إنشاء الدور المحدد", 500);
                    }
                }

                var user = await CreateUserAsync(model);
                if (user == null)
                {
                    return Response<string>.Failure("حدث خطأ أثناء إنشاء المستخدم", 500);
                }
                await _userCleanup.ScheduleUserCleanupAsync(user.Id, model.Email);

                var roleAddResult = await _userManager.AddToRoleAsync(user, model.Role);
                if (!roleAddResult.Succeeded)
                {
                    return Response<string>.Failure("حدث خطأ أثناء إسناد الدور للمستخدم", 500);
                }

                if (!string.IsNullOrEmpty(model.FCMToken))
                {
                    await _notificationService.RegisterDeviceAsync(user.Id, model.FCMToken, model.DeviceType);
                }

                if (model.Role == "Driver")
                {
                    var scooterResult = await RegisterDriverScooterAsync(user.Id, model);
                    if (!scooterResult.IsSuccess)
                    {
                        return Response<string>.Failure("فشل في تسجيل سكوتر السائق", 500);
                    }
                }
                if (model.Role is "Client" or "Driver")
                {
                    var otpResult = await _OTP.SendRegisterationOTPAsync(model.Email);
                    if (!otpResult.IsSuccess)
                    {
                        return Response<string>.Failure("حدث خطأ أثناء إرسال الرمز التاكيدى الى البريد الإلكتروني", 500);
                    }
                }
                else
                {
                    user.EmailConfirmed = true;
                    user.IsAvailable = true;
                    user.LastHandledChatAt = DateTime.Now.ToEgyptTime();
                    await _userManager.UpdateAsync(user);
                }

                await transaction.CommitAsync();

                var msg = model.Role is "Client" or "Driver"
                    ? "تم التسجيل بنجاح. راجع بريدك الإلكتروني لتأكيد الحساب"
                    : "تم التسجيل بنجاح. يمكنك تسجيل الدخول الآن";
                return Response<string>.Success(msg, msg, 201);
            }
            catch (Exception ex)
            {
                if (transaction != null)
                {
                    await transaction.RollbackAsync();
                }

                Log.Error(ex, "AuthService error");
                return Response<string>.Failure("حدث خطأ في الخادم. يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<LoginResponseDTO>> LoginAsync(LoginDTO model)
        {
            try
            {
                var user = await _userManager.FindByEmailAsync(model.Email);
                if (user == null || !await _userManager.CheckPasswordAsync(user, model.Password))
                {
                    return Response<LoginResponseDTO>.Failure("البريد الإلكتروني أو كلمة المرور غير صحيحة", 400);
                }

                // for testing account bank
                //var user = await _userManager.FindByEmailAsync("mohdali30060@gmail.com");

                if(user.IsBlocked)
                {
                    return Response<LoginResponseDTO>.Failure("تم تعطيل حسابك ، يُرجى التواصل مع الدعم", 403);
                }
                if (!user.EmailConfirmed)
                {
                    return Response<LoginResponseDTO>.Failure("يرجى تأكيد او تسجيل بريدك الإلكتروني قبل تسجيل الدخول", 400);
                }

                if (!string.IsNullOrEmpty(model.FCMToken)) 
                {
                   
                    await _notificationService.RegisterDeviceAsync(user.Id, model.FCMToken,model.DeviceType);
                }
                var token = await _jwtService.GenerateJwtToken(user);
                var refreshToken = "";
                DateTime refreshTokenExpiration;

                var RefreshToken = _jwtService.CreateRefreshToken();
                refreshToken = RefreshToken.Token;
                refreshTokenExpiration = RefreshToken.ExpiresOn;
                if (user.RefreshTokens == null)
                {
                    user.RefreshTokens = new List<RefreshToken>();
                }
                user.RefreshTokens!.Add(RefreshToken);
                await _userManager.UpdateAsync(user);

                var roles = await _userManager.GetRolesAsync(user);
                if(roles.Contains("Admin")||roles.Contains("Dispatcher"))
                {
                    _onlineTrackerService.MarkOnline(user.Id,"Admin");
                }
                return Response<LoginResponseDTO>.Success(new LoginResponseDTO
                {
                    UserId = user.Id,
                    Name = user.FullName,
                    Gender = user.Gender,
                    IsAuthenticated = true,
                    Token = new JwtSecurityTokenHandler().WriteToken(token),
                    RefreshToken = refreshToken,
                    RefreshTokenExpiration = refreshTokenExpiration,
                    Roles = roles.ToList(),
                    ProfilePicture = user.ProfilePicture ?? "",
                    NationalId = user.NationalId ?? "",
                    License = user.License ?? "",
                }, "تم تسجيل الدخول بنجاح", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "AuthService error");
                return Response<LoginResponseDTO>.Failure("حدث خطأ في الخادم. يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<string>> ConfirmOtp(string otp, OtpType type, string email)
        {
            try
            {
                var otpData = type == OtpType.Register ? _cacheService.GetData<OtpCacheModel>($"OTP_Register_{email}")
                    : _cacheService.GetData<OtpCacheModel>($"OTP_ResetPassword_{email}");

                if (otpData == null || string.IsNullOrEmpty(otpData.Otp) || otp != otpData.Otp)
                {
                    return Response<string>.Failure("رمز التحقق منتهي او غير صالح", 400);
                }

                var user = await _userManager.FindByEmailAsync(email);
                if (user == null)
                {
                    return Response<string>.Failure("المستخدم غير موجود", 400);
                }
                if (type == OtpType.Register)
                {
                    user.EmailConfirmed = true;
                    await _userManager.UpdateAsync(user);
                    await _cacheService.RemoveDataAsync($"OTP_Register_{email}");
                    return Response<string>.Success(user.Id, "تم تأكيد حسابك بنجاح ، برجاء التوجه الان الى صفحة تسجيل الدخول", 200);
                }
                else
                {
                    await _cacheService.RemoveDataAsync($"OTP_ResetPassword_{email}");
                    // Mark that this email passed OTP verification so ResetPassword can trust it.
                    _cacheService.SetData($"OTP_ResetVerified_{email}", true, TimeSpan.FromMinutes(10));
                    return Response<string>.Success("تم تأكيد رمز التحقق بنجاح", "تم تأكيد رمز التحقق بنجاح", 200);
                }
            }
            catch (Exception ex)
            {
                Log.Error(ex, "AuthService error");
                return Response<string>.Failure("حدث خطأ في الخادم. يرجى المحاولة لاحقًا.", 500);
            }

        }

        public async Task<Response<string>> LogoutAsync(string refreshToken)
        {
            try
            {
                var egyptTime = DateTime.Now.ToEgyptTime();
                var user = await _userManager.Users
                .FirstOrDefaultAsync(u => u.RefreshTokens != null &&
                    u.RefreshTokens.Any(t =>
                        t.Token == refreshToken &&
                        t.RevokedOn == null &&
                        t.ExpiresOn > egyptTime
                    )
                );
                if (user == null)
                {
                    return Response<string>.Failure("المستخدم غير موجود او غير نشط", 404);
                }

                var token = user.RefreshTokens?.FirstOrDefault(t => t.Token == refreshToken && t.IsActive);
                if (token == null)
                {
                    return Response<string>.Failure("المستخدم غير نشط او سجل خروج بالفعل", 400);
                }

                token.RevokedOn = DateTime.Now.ToEgyptTime();

                if (await _userManager.IsInRoleAsync(user, "Driver"))
                {
                    user.IsAvailable = false;
                }

                var updateResult = await _userManager.UpdateAsync(user);

                if (!updateResult.Succeeded)
                {
                    var errors = updateResult.Errors.Select(e => e.Description).ToList();
                    return Response<string>.Failure($"حدث خطأ أثناء تسجيل الخروج: {string.Join(", ", errors)}", 500);
                }

                if (!user.RefreshTokens!.Any())
                {
                    _onlineTrackerService.MarkOffline(user.Id);
                }
                return Response<string>.Success("تم تسجيل الخروج بنجاح", "تم تسجيل الخروج بنجاح", 200);

            }
            catch (Exception ex)
            {
                Log.Error(ex, "AuthService error");
                return Response<string>.Failure("حدث خطأ في الخادم. يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<string>> ChangePasswordAsync(ChangePasswordDTO model)
        {
            try
            {
                var user = await _userManager.FindByEmailAsync(model.Email);
                if (user == null)
                {
                    return Response<string>.Failure("المستخدم غير موجود", 404);
                }

                var isPasswordValid = await _userManager.CheckPasswordAsync(user, model.OldPassword);
                if (!isPasswordValid)
                {
                    return Response<string>.Failure("كلمة المرور القديمة غير صحيحة", 400);
                }

                var result = await _userManager.ChangePasswordAsync(user, model.OldPassword, model.NewPassword);
                if (!result.Succeeded)
                {
                    return Response<string>.Failure("حدث خطأ أثناء تغيير كلمة المرور", "حدث خطأ أثناء تغيير كلمة المرور", 400);
                }

                return Response<string>.Success("تم تغيير كلمة المرور بنجاح", "تم تغيير كلمة المرور بنجاح", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "AuthService error");
                return Response<string>.Failure("حدث خطأ في الخادم. يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<string>> ForgotPasswordAsync(string email)
        {
            try
            {
                var user = await _userManager.FindByEmailAsync(email);
                if (user == null)
                {
                    return Response<string>.Failure("المستخدم غير موجود", 404);
                }

                var otpResult = await _OTP.SendResetPasswordOTPAsync(email);
                if (!otpResult.IsSuccess)
                {
                    return Response<string>.Failure("حدث خطأ أثناء إرسال البريد الإلكتروني", "حدث خطأ أثناء إرسال البريد الإلكتروني", 400);
                }

                return Response<string>.Success("تم إرسال رمز التحقق إلى بريدك الإلكتروني", "تم إرسال رمز التحقق إلى بريدك الإلكتروني", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "AuthService error");
                return Response<string>.Failure("حدث خطأ في الخادم. يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<string>> ResetPasswordAsync(ResetPasswordDTO model)
        {
            try
            {
                var user = await _userManager.FindByEmailAsync(model.Email);
                if (user == null)
                {
                    return Response<string>.Failure("المستخدم غير موجود", 404);
                }

                // Require that the OTP was actually verified for this email before allowing reset.
                var verified = _cacheService.GetData<bool>($"OTP_ResetVerified_{model.Email}");
                if (!verified)
                {
                    return Response<string>.Failure("لم يتم التحقق من رمز التحقق. يرجى تأكيد الرمز أولاً.", 403);
                }

                var removeResult = await _userManager.RemovePasswordAsync(user);
                if (!removeResult.Succeeded)
                {
                    return Response<string>.Failure("حدث خطأ اثناء تغيير كلمة المرور", "حدث خطأ اثناء تغيير كلمة المرور", 400);
                }

                var addResult = await _userManager.AddPasswordAsync(user, model.NewPassword);
                if (!addResult.Succeeded)
                {
                    return Response<string>.Failure("حدث خطأ اثناء تغيير كلمة المرور", "حدث خطأ اثناء تغيير كلمة المرور", 400);
                }

                // Consume the verification flag so it can't be replayed.
                await _cacheService.RemoveDataAsync($"OTP_ResetVerified_{model.Email}");

                return Response<string>.Success("تم تغيير كلمة المرور بنجاح", "تم تغيير كلمة المرور بنجاح", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "AuthService error");
                return Response<string>.Failure("حدث خطأ في الخادم. يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<bool>> ResendOtpAsync(string email, OtpType otpType)
        {
            try
            {
                
                var user = await _userManager.FindByEmailAsync(email);
                if (user == null)
                {
                    return Response<bool>.Failure("البريد الإلكتروني غير موجود", 404);
                }

                var otpResult = await _OTP.ResendOtpAsync(email, otpType);
           
                if (otpResult.IsSuccess)
                {
                    return Response<bool>.Success(true, "تم إرسال رمز التحقق بنجاح.", 200);
                }

                return Response<bool>.Failure(otpResult.Message, 400);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "AuthService error");
                return Response<bool>.Failure("فشل في إرسال رمز التحقق. يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<object>> LoginToDashboardAsync(LoginDTO model)
        {
            try
            {
                var response = await LoginAsync(model);
                if (!response.IsSuccess)
                {
                    return Response<object>.Failure(response.Message, response.StatusCode);
                }

                await AddTokenToCookie(response.Data.RefreshToken, response.Data.RefreshTokenExpiration);

                return Response<object>.Success(new
                {
                    AccessToken = response.Data.Token,
                    ExpiresIn = DateTime.Now.ToEgyptTime().AddDays(1),
                    User = new 
                    {
                        UserId = response.Data.UserId,
                        Name = response.Data.Name,
                        Gender = response.Data.Gender,
                        IsAuthenticated = true,
                        Role = response.Data.Roles.FirstOrDefault(),
                        ProfilePicture = response.Data.ProfilePicture,
                        NationalId = response.Data.NationalId
                    }
                }, "تم تسجيل الدخول بنجاح", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "AuthService error");
                return Response<object>.Failure("حدث خطأ في الخادم. يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<string>> LogoutFromDashboardAsync()
        {
            try
            {
                var refreshToken = _httpContextAccessor.HttpContext!.Request.Cookies["refreshToken"]!;

                var user = await _userManager.Users
                .FirstOrDefaultAsync(u => u.RefreshTokens != null &&
                    u.RefreshTokens.Any(t =>
                        t.Token == refreshToken &&
                        t.RevokedOn == null &&
                        t.ExpiresOn > DateTime.Now.ToEgyptTime()
                    )
                );
                if (user == null)
                {
                    return Response<string>.Failure("المستخدم غير موجود او غير نشط", 404);
                }

                var token = user.RefreshTokens?.FirstOrDefault(t => t.Token == refreshToken && t.IsActive);
                if (token == null)
                {
                    return Response<string>.Failure("المستخدم غير نشط او سجل خروج بالفعل", 400);
                }

                token.RevokedOn = DateTime.Now.ToEgyptTime();
                var updateResult = await _userManager.UpdateAsync(user);
                if (!updateResult.Succeeded)
                {
                    var errors = updateResult.Errors.Select(e => e.Description).ToList();
                    return Response<string>.Failure($"حدث خطأ أثناء تسجيل الخروج: {string.Join(", ", errors)}", 500);
                }

                _httpContextAccessor.HttpContext!.Response.Cookies.Delete("refreshToken");
                _httpContextAccessor.HttpContext!.Response.Cookies.Delete("refreshTokenExpiration");

                if (!user.RefreshTokens!.Any())
                {
                    _onlineTrackerService.MarkOffline(user.Id);
                }
                return Response<string>.Success("تم تسجيل الخروج بنجاح", "تم تسجيل الخروج بنجاح", 200);

            }
            catch (Exception ex)
            {
                Log.Error(ex, "AuthService error");
                return Response<string>.Failure("حدث خطأ في الخادم. يرجى المحاولة لاحقًا.", 500);
            }
        }

        // Helpers
        private async Task<ApplicationUser> CreateUserAsync(RegisterDTO model)
        {
            try
            {
              var photoPath=  await _cloudinaryService.UploadFileAsync(model.Photo, "ProfilePictures");
                var user = new ApplicationUser
                {
                    FullName = model.FullName,
                    UserName = model.Email,
                    Email = model.Email,
                    PhoneNumber = model.Phone,
                    Gender = model.Gender,
                    ProfilePicture = photoPath.Url,
                    License=model.DriverLicense,
                    NationalId = model.NationalId,
                };

                var result = await _userManager.CreateAsync(user, model.Password);
                if (!result.Succeeded)
                {
                    return null;
                }
                return user;
            }
            catch (Exception ex)
            {
                Log.Error(ex, "AuthService error creating driver user");
                return null;
            }
        }
        private async Task<Response<string>> RegisterDriverScooterAsync(string driverId, RegisterDTO model)
        {
            if ((model.ScoterType == ScooterType.Gasoline && model.ScoterLicense == null) || model.ScoterType == null)
            {
                return Response<string>.Failure("يرجى إدخال بيانات السكوتر للسائق", 400);
            }

            var scooter = new Scooter
            {
                DriverId = driverId,
                License = model.ScoterLicense!,
                Type = model.ScoterType.Value
            };

            await _unitOfWork.Scooters.AddAsync(scooter);
            await _unitOfWork.SaveAsync();

            return Response<string>.Success("تم تسجيل السكوتر", "تم تسجيل السكوتر", 200);
        }

        private Task AddTokenToCookie(string refreshToken, DateTime refreshTokenExpiration)
        {
            var cookieOptions = new CookieOptions
            {
                HttpOnly = true,
                Expires = refreshTokenExpiration,
                SameSite = SameSiteMode.Strict,
                Secure = true
            };
            _httpContextAccessor.HttpContext!.Response.Cookies.Append("refreshToken", refreshToken, cookieOptions);
            _httpContextAccessor.HttpContext!.Response.Cookies.Append(
                    "refreshTokenExpiration",
                    refreshTokenExpiration.ToString("o"),
                    new CookieOptions
                    {
                        HttpOnly = true,
                        Secure = true,
                        SameSite = SameSiteMode.None,
                        Expires = new DateTimeOffset(refreshTokenExpiration)
                    });

            return Task.CompletedTask;
        }

    }
}