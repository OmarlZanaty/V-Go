using CloudinaryDotNet.Actions;
using FluentValidation;
using Google.Apis.Auth;
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
using FirebaseAdmin.Auth;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.ExternalService.UserCleanUpService;
using Masafet_Elseka.Infrastructure.Services.OnlineTrackerService;
using Masafet_Elseka.Infrastructure.UOW;
using Masafet_Elseka.Infrastructure.Validations;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
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
        private readonly IConfiguration _config;

        // Cross-app sign-in guards — friendly Arabic messages shown to the user.
        private const string CaptainOnRiderMessage =
            "عذرًا، هذا الحساب مُسجَّل كحساب كابتن 🛵\nلا يمكنك الدخول من تطبيق الركاب، يُرجى استخدام تطبيق الكابتن.";
        private const string RiderOnCaptainMessage =
            "عذرًا، هذا الحساب مُسجَّل كحساب راكب 🧍\nلا يمكنك الدخول من تطبيق الكباتن، يُرجى استخدام تطبيق الركاب.";

        public AuthService(UserManager<ApplicationUser> userManager, RoleManager<IdentityRole> roleManager, OTP oTP, IJWTService jWTService,
            ICacheService cacheService, ICloudinaryService cloudinaryService, IUnitOfWork unitOfWork, Context context, IUserCleanupService userCleanup, IHttpContextAccessor httpContextAccessor, INotificationService notificationService, OnlineTrackerService.OnlineTrackerService onlineTrackerService, IConfiguration config)
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
            _config = config;
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
                    // Generic message — does not confirm whether the email is registered
                    // (prevents account enumeration).
                    return Response<string>.Failure("تعذّر إتمام التسجيل بهذه البيانات. إذا كان لديك حساب بالفعل، يرجى تسجيل الدخول أو استخدام استعادة كلمة المرور.", 400);
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

        // Phone OTP login: the app verifies the phone with Firebase Phone Auth and
        // sends the resulting ID token. We verify it, then log the matching user in
        // — or signal a new user so the app can complete sign-up.
        public async Task<Response<LoginResponseDTO>> LoginWithPhoneAsync(PhoneLoginDTO model)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(model?.Phone) || string.IsNullOrWhiteSpace(model.Password))
                    return Response<LoginResponseDTO>.Failure("رقم الهاتف وكلمة المرور مطلوبان", 400);

                var phone = NormalizePhone(model.Phone);
                var user = await _userManager.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phone);
                if (user == null)
                    return Response<LoginResponseDTO>.Failure("لا يوجد حساب بهذا الرقم، يرجى إنشاء حساب جديد", 404);

                // Captain accounts cannot sign in to the rider app.
                if (await _userManager.IsInRoleAsync(user, "Driver"))
                    return Response<LoginResponseDTO>.Failure(CaptainOnRiderMessage, 403);

                if (user.IsBlocked)
                    return Response<LoginResponseDTO>.Failure("تم تعطيل حسابك، يُرجى التواصل مع الدعم", 403);

                if (!await _userManager.CheckPasswordAsync(user, model.Password))
                    return Response<LoginResponseDTO>.Failure("رقم الهاتف أو كلمة المرور غير صحيحة", 401);

                if (!string.IsNullOrEmpty(model.FCMToken))
                    await _notificationService.RegisterDeviceAsync(user.Id, model.FCMToken, model.DeviceType);

                var token = await _jwtService.GenerateJwtToken(user);
                var refresh = _jwtService.CreateRefreshToken();
                user.RefreshTokens ??= new List<RefreshToken>();
                user.RefreshTokens.Add(refresh);
                await _userManager.UpdateAsync(user);

                var roles = await _userManager.GetRolesAsync(user);
                return Response<LoginResponseDTO>.Success(new LoginResponseDTO
                {
                    UserId = user.Id,
                    Name = user.FullName,
                    Gender = user.Gender,
                    IsAuthenticated = true,
                    IsNewUser = false,
                    Phone = phone,
                    Token = new JwtSecurityTokenHandler().WriteToken(token),
                    RefreshToken = refresh.Token,
                    RefreshTokenExpiration = refresh.ExpiresOn,
                    Roles = roles.ToList(),
                    ProfilePicture = user.ProfilePicture ?? "",
                    NationalId = user.NationalId ?? "",
                    License = user.License ?? "",
                }, "تم تسجيل الدخول بنجاح", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Phone login error");
                return Response<LoginResponseDTO>.Failure("حدث خطأ أثناء تسجيل الدخول، يرجى المحاولة لاحقًا.", 500);
            }
        }

        // Phone OTP login for the captain app — DRIVER ROLE ONLY. A new phone, or an
        // existing non-driver (e.g. a rider/Client account), is sent to captain sign-up
        // (IsNewUser = true) instead of being granted a captain session.
        public async Task<Response<LoginResponseDTO>> LoginDriverWithPhoneAsync(PhoneLoginDTO model)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(model?.Phone) || string.IsNullOrWhiteSpace(model.Password))
                    return Response<LoginResponseDTO>.Failure("رقم الهاتف وكلمة المرور مطلوبان", 400);

                var phone = NormalizePhone(model.Phone);
                var user = await _userManager.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phone);
                if (user == null)
                    return Response<LoginResponseDTO>.Failure("لا يوجد حساب بهذا الرقم، يرجى إنشاء حساب جديد", 404);

                if (user.IsBlocked)
                    return Response<LoginResponseDTO>.Failure("تم تعطيل حسابك، يُرجى التواصل مع الدعم", 403);

                var roles = await _userManager.GetRolesAsync(user);
                if (!roles.Contains("Driver"))
                {
                    // Phone belongs to a rider (Client) account → cannot use the captain app.
                    return Response<LoginResponseDTO>.Failure(RiderOnCaptainMessage, 403);
                }

                if (!await _userManager.CheckPasswordAsync(user, model.Password))
                    return Response<LoginResponseDTO>.Failure("رقم الهاتف أو كلمة المرور غير صحيحة", 401);

                if (!string.IsNullOrEmpty(model.FCMToken))
                    await _notificationService.RegisterDeviceAsync(user.Id, model.FCMToken, model.DeviceType);

                var token = await _jwtService.GenerateJwtToken(user);
                var refresh = _jwtService.CreateRefreshToken();
                user.RefreshTokens ??= new List<RefreshToken>();
                user.RefreshTokens.Add(refresh);
                await _userManager.UpdateAsync(user);

                return Response<LoginResponseDTO>.Success(new LoginResponseDTO
                {
                    UserId = user.Id,
                    Name = user.FullName,
                    Gender = user.Gender,
                    IsAuthenticated = true,
                    IsNewUser = false,
                    Phone = phone,
                    Token = new JwtSecurityTokenHandler().WriteToken(token),
                    RefreshToken = refresh.Token,
                    RefreshTokenExpiration = refresh.ExpiresOn,
                    Roles = roles.ToList(),
                    ProfilePicture = user.ProfilePicture ?? "",
                    NationalId = user.NationalId ?? "",
                    License = user.License ?? "",
                }, "تم تسجيل الدخول بنجاح", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Phone driver login error");
                return Response<LoginResponseDTO>.Failure("حدث خطأ أثناء تسجيل الدخول، يرجى المحاولة لاحقًا.", 500);
            }
        }

        // Phone OTP sign-up: create a passwordless, phone-verified client account
        // (email optional), then log them in immediately.
        public async Task<Response<LoginResponseDTO>> RegisterWithPhoneAsync(PhoneRegisterDTO model)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(model?.Phone) || string.IsNullOrWhiteSpace(model.Password))
                    return Response<LoginResponseDTO>.Failure("رقم الهاتف وكلمة المرور مطلوبان", 400);
                if (string.IsNullOrWhiteSpace(model.FullName))
                    return Response<LoginResponseDTO>.Failure("الاسم مطلوب", 400);

                var phone = NormalizePhone(model.Phone);

                var existing = await _userManager.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phone);
                if (existing != null)
                    return Response<LoginResponseDTO>.Failure("هذا الرقم مسجّل بالفعل، يرجى تسجيل الدخول.", 409);

                if (!string.IsNullOrWhiteSpace(model.Email))
                {
                    var byEmail = await _userManager.FindByEmailAsync(model.Email);
                    if (byEmail != null)
                        return Response<LoginResponseDTO>.Failure("البريد الإلكتروني مستخدم بالفعل.", 409);
                }

                var user = new ApplicationUser
                {
                    UserName = phone,
                    PhoneNumber = phone,
                    PhoneNumberConfirmed = false,
                    FullName = model.FullName.Trim(),
                    Email = string.IsNullOrWhiteSpace(model.Email) ? null : model.Email.Trim(),
                    EmailConfirmed = true,
                    Gender = string.IsNullOrWhiteSpace(model.Gender) ? "Male" : model.Gender,
                    CreatedAt = DateTime.UtcNow,
                };

                var createResult = await _userManager.CreateAsync(user, model.Password);
                if (!createResult.Succeeded)
                {
                    var err = string.Join(" ", createResult.Errors.Select(e => e.Description));
                    return Response<LoginResponseDTO>.Failure(
                        string.IsNullOrWhiteSpace(err) ? "تعذّر إنشاء الحساب" : err, 400);
                }

                await _userManager.AddToRoleAsync(user, "Client");

                if (!string.IsNullOrEmpty(model.FCMToken))
                    await _notificationService.RegisterDeviceAsync(user.Id, model.FCMToken, model.DeviceType);

                var token = await _jwtService.GenerateJwtToken(user);
                var refresh = _jwtService.CreateRefreshToken();
                user.RefreshTokens ??= new List<RefreshToken>();
                user.RefreshTokens.Add(refresh);
                await _userManager.UpdateAsync(user);

                var roles = await _userManager.GetRolesAsync(user);
                return Response<LoginResponseDTO>.Success(new LoginResponseDTO
                {
                    UserId = user.Id,
                    Name = user.FullName,
                    Gender = user.Gender,
                    IsAuthenticated = true,
                    IsNewUser = false,
                    Phone = phone,
                    Token = new JwtSecurityTokenHandler().WriteToken(token),
                    RefreshToken = refresh.Token,
                    RefreshTokenExpiration = refresh.ExpiresOn,
                    Roles = roles.ToList(),
                    ProfilePicture = user.ProfilePicture ?? "",
                    NationalId = user.NationalId ?? "",
                    License = user.License ?? "",
                }, "تم إنشاء الحساب بنجاح", 201);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Phone register error");
                return Response<LoginResponseDTO>.Failure("حدث خطأ أثناء إنشاء الحساب، يرجى المحاولة لاحقًا.", 500);
            }
        }

        // Phone OTP sign-up for a driver (captain): passwordless, phone-verified,
        // with national id / license + scooter, then logged in.
        public async Task<Response<LoginResponseDTO>> RegisterDriverWithPhoneAsync(PhoneRegisterDriverDTO model)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(model?.Phone) || string.IsNullOrWhiteSpace(model.Password))
                    return Response<LoginResponseDTO>.Failure("رقم الهاتف وكلمة المرور مطلوبان", 400);
                if (string.IsNullOrWhiteSpace(model.FullName))
                    return Response<LoginResponseDTO>.Failure("الاسم مطلوب", 400);

                var scooterType = (ScooterType)model.ScooterType;
                if (scooterType == ScooterType.Gasoline && string.IsNullOrWhiteSpace(model.ScooterLicense))
                    return Response<LoginResponseDTO>.Failure("يرجى إدخال رخصة السكوتر (بنزين)", 400);

                var phone = NormalizePhone(model.Phone);

                var user = await _userManager.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phone);
                if (user != null)
                {
                    if (user.IsBlocked)
                        return Response<LoginResponseDTO>.Failure("تم تعطيل حسابك، يُرجى التواصل مع الدعم", 403);

                    var currentRoles = await _userManager.GetRolesAsync(user);
                    if (currentRoles.Contains("Driver"))
                        return Response<LoginResponseDTO>.Failure("هذا الرقم مسجّل بالفعل ككابتن، يرجى تسجيل الدخول.", 409);

                    // Phone belongs to a rider (Client) account → cannot register as captain.
                    return Response<LoginResponseDTO>.Failure(RiderOnCaptainMessage, 403);
                }
                else
                {
                    if (!string.IsNullOrWhiteSpace(model.Email))
                    {
                        var byEmail = await _userManager.FindByEmailAsync(model.Email);
                        if (byEmail != null)
                            return Response<LoginResponseDTO>.Failure("البريد الإلكتروني مستخدم بالفعل.", 409);
                    }

                    user = new ApplicationUser
                    {
                        UserName = phone,
                        PhoneNumber = phone,
                        PhoneNumberConfirmed = false,
                        FullName = model.FullName.Trim(),
                        Email = string.IsNullOrWhiteSpace(model.Email) ? null : model.Email.Trim(),
                        EmailConfirmed = true,
                        Gender = string.IsNullOrWhiteSpace(model.Gender) ? "Male" : model.Gender,
                        NationalId = model.NationalId,
                        License = model.DriverLicense,
                        CreatedAt = DateTime.UtcNow,
                    };

                    var createResult = await _userManager.CreateAsync(user, model.Password);
                    if (!createResult.Succeeded)
                    {
                        var err = string.Join(" ", createResult.Errors.Select(e => e.Description));
                        return Response<LoginResponseDTO>.Failure(
                            string.IsNullOrWhiteSpace(err) ? "تعذّر إنشاء الحساب" : err, 400);
                    }
                }

                if (!await _userManager.IsInRoleAsync(user, "Driver"))
                    await _userManager.AddToRoleAsync(user, "Driver");

                var scooter = new Scooter
                {
                    DriverId = user.Id,
                    License = model.ScooterLicense,
                    Type = scooterType,
                };
                await _unitOfWork.Scooters.AddAsync(scooter);
                await _unitOfWork.SaveAsync();

                if (!string.IsNullOrEmpty(model.FCMToken))
                    await _notificationService.RegisterDeviceAsync(user.Id, model.FCMToken, model.DeviceType);

                var token = await _jwtService.GenerateJwtToken(user);
                var refresh = _jwtService.CreateRefreshToken();
                user.RefreshTokens ??= new List<RefreshToken>();
                user.RefreshTokens.Add(refresh);
                await _userManager.UpdateAsync(user);

                var roles = await _userManager.GetRolesAsync(user);
                return Response<LoginResponseDTO>.Success(new LoginResponseDTO
                {
                    UserId = user.Id,
                    Name = user.FullName,
                    Gender = user.Gender,
                    IsAuthenticated = true,
                    IsNewUser = false,
                    Phone = phone,
                    Token = new JwtSecurityTokenHandler().WriteToken(token),
                    RefreshToken = refresh.Token,
                    RefreshTokenExpiration = refresh.ExpiresOn,
                    Roles = roles.ToList(),
                    ProfilePicture = user.ProfilePicture ?? "",
                    NationalId = user.NationalId ?? "",
                    License = user.License ?? "",
                }, "تم إنشاء حساب الكابتن بنجاح", 201);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Phone driver register error");
                return Response<LoginResponseDTO>.Failure("حدث خطأ أثناء إنشاء الحساب، يرجى المحاولة لاحقًا.", 500);
            }
        }

        // Drives the "set password" (new) vs "enter password" (returning) branch
        // after the user types their phone number.
        public async Task<Response<bool>> CheckPhoneExistsAsync(string phone)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(phone))
                    return Response<bool>.Failure("رقم الهاتف مطلوب", 400);

                var normalized = NormalizePhone(phone);
                var exists = await _userManager.Users.AnyAsync(u => u.PhoneNumber == normalized);
                return Response<bool>.Success(exists, exists ? "الرقم مسجّل" : "رقم جديد", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "CheckPhoneExists error");
                return Response<bool>.Failure("حدث خطأ، يرجى المحاولة لاحقًا.", 500);
            }
        }

        // Forgot-password for phone accounts: the app verifies ownership with a
        // Firebase Phone-Auth OTP (the only remaining OTP use), then we set the new
        // password. Works whether or not the account already had a password.
        public async Task<Response<string>> ResetPhonePasswordAsync(PhoneResetPasswordDTO model)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(model?.IdToken))
                    return Response<string>.Failure("رمز التحقق مفقود", 400);
                if (string.IsNullOrWhiteSpace(model.NewPassword))
                    return Response<string>.Failure("كلمة المرور الجديدة مطلوبة", 400);

                FirebaseToken decoded;
                try
                {
                    decoded = await FirebaseAuth.DefaultInstance.VerifyIdTokenAsync(model.IdToken);
                }
                catch
                {
                    return Response<string>.Failure("رمز التحقق غير صالح أو منتهي الصلاحية، حاول مجددًا.", 401);
                }

                var phone = decoded.Claims.TryGetValue("phone_number", out var p) ? p?.ToString() : null;
                if (string.IsNullOrWhiteSpace(phone))
                    return Response<string>.Failure("تعذّر قراءة رقم الهاتف من رمز التحقق", 400);

                var user = await _userManager.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phone);
                if (user == null)
                    return Response<string>.Failure("لا يوجد حساب بهذا الرقم", 404);

                IdentityResult result;
                if (await _userManager.HasPasswordAsync(user))
                {
                    var resetToken = await _userManager.GeneratePasswordResetTokenAsync(user);
                    result = await _userManager.ResetPasswordAsync(user, resetToken, model.NewPassword);
                }
                else
                {
                    result = await _userManager.AddPasswordAsync(user, model.NewPassword);
                }

                if (!result.Succeeded)
                {
                    var err = string.Join(" ", result.Errors.Select(e => e.Description));
                    return Response<string>.Failure(
                        string.IsNullOrWhiteSpace(err) ? "تعذّر تعيين كلمة المرور" : err, 400);
                }

                return Response<string>.Success("تم تعيين كلمة المرور بنجاح", "تم تعيين كلمة المرور بنجاح", 200);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Phone reset password error");
                return Response<string>.Failure("حدث خطأ، يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<string>> ConfirmOtp(string otp, OtpType type, string email)
        {
            try
            {
                // Rate-limit verification attempts to prevent brute-forcing the 6-digit code.
                var attemptsKey = $"OTP_Attempts_{type}_{email}";
                var attempts = _cacheService.GetData<int>(attemptsKey);
                if (attempts >= 5)
                {
                    return Response<string>.Failure("تم تجاوز عدد محاولات إدخال الرمز المسموح بها. يرجى طلب رمز جديد لاحقًا.", 429);
                }

                var otpData = type == OtpType.Register ? _cacheService.GetData<OtpCacheModel>($"OTP_Register_{email}")
                    : _cacheService.GetData<OtpCacheModel>($"OTP_ResetPassword_{email}");

                if (otpData == null || string.IsNullOrEmpty(otpData.Otp) || otp != otpData.Otp)
                {
                    _cacheService.SetData(attemptsKey, attempts + 1, TimeSpan.FromMinutes(10));
                    return Response<string>.Failure("رمز التحقق منتهي او غير صالح", 400);
                }

                // Valid code — clear the failed-attempt counter.
                await _cacheService.RemoveDataAsync(attemptsKey);

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
                var refreshToken = _httpContextAccessor.HttpContext?.Request.Cookies["refreshToken"];

                // If the cookie is already gone (e.g. the admin cleared cookies) there is
                // nothing to revoke — treat logout as an idempotent success and make sure any
                // stale cookies are cleared, instead of returning a confusing server error.
                if (string.IsNullOrEmpty(refreshToken))
                {
                    _httpContextAccessor.HttpContext?.Response.Cookies.Delete("refreshToken");
                    _httpContextAccessor.HttpContext?.Response.Cookies.Delete("refreshTokenExpiration");
                    return Response<string>.Success("تم تسجيل الخروج بنجاح", "تم تسجيل الخروج بنجاح", 200);
                }

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
                    // Cookie present but no matching active token — already effectively logged
                    // out. Clear the stale cookies and return success (idempotent).
                    _httpContextAccessor.HttpContext?.Response.Cookies.Delete("refreshToken");
                    _httpContextAccessor.HttpContext?.Response.Cookies.Delete("refreshTokenExpiration");
                    return Response<string>.Success("تم تسجيل الخروج بنجاح", "تم تسجيل الخروج بنجاح", 200);
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

        // ── Google Sign-In (native token) ──────────────────────────────────────

        // Web + both Android OAuth client IDs. The id_token's `aud` may be any of
        // these depending on how google_sign_in is configured on the device.
        private static readonly string[] GoogleAllowedAudiences = new[]
        {
            "792221536894-jqrpntom44mkat6kfn1lj916g5lp79a0.apps.googleusercontent.com", // Web (backend)
            "792221536894-qq168obg2lvths4cc55t8eme5b64egl7.apps.googleusercontent.com", // Rider Android
            "792221536894-v457jh2lamlvstq5nrv5vte758a7ifpa.apps.googleusercontent.com", // Captain Android
        };

        private string[] GetGoogleAudiences()
        {
            var configured = _config["Google:WebClientId"];
            if (string.IsNullOrWhiteSpace(configured) || GoogleAllowedAudiences.Contains(configured))
                return GoogleAllowedAudiences;
            return GoogleAllowedAudiences.Append(configured).ToArray();
        }

        // Decodes the JWT payload (no verification) to read the `aud` claim — for diagnostics only.
        private static string ExtractAud(string jwt)
        {
            try
            {
                var parts = jwt.Split('.');
                if (parts.Length < 2) return "(malformed)";
                var payload = parts[1].Replace('-', '+').Replace('_', '/');
                switch (payload.Length % 4) { case 2: payload += "=="; break; case 3: payload += "="; break; }
                var json = Encoding.UTF8.GetString(Convert.FromBase64String(payload));
                using var doc = System.Text.Json.JsonDocument.Parse(json);
                return doc.RootElement.TryGetProperty("aud", out var aud) ? aud.GetString() ?? "(null)" : "(no aud)";
            }
            catch { return "(decode failed)"; }
        }

        public async Task<Response<LoginResponseDTO>> GoogleTokenLoginAsync(GoogleTokenLoginDTO model)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(model?.IdToken))
                    return Response<LoginResponseDTO>.Failure("رمز Google مفقود", 400);

                GoogleJsonWebSignature.Payload payload;
                try
                {
                    payload = await GoogleJsonWebSignature.ValidateAsync(
                        model.IdToken,
                        new GoogleJsonWebSignature.ValidationSettings
                        {
                            Audience = GetGoogleAudiences()
                        });
                }
                catch (InvalidJwtException ex)
                {
                    Log.Warning(ex, "Invalid Google ID token. Token aud was: {Aud}", ExtractAud(model.IdToken));
                    return Response<LoginResponseDTO>.Failure("رمز Google غير صالح أو منتهي الصلاحية.", 401);
                }

                var email = payload.Email?.ToLowerInvariant();
                if (string.IsNullOrWhiteSpace(email))
                    return Response<LoginResponseDTO>.Failure("لم يتم توفير البريد الإلكتروني من Google.", 400);

                var user = await _userManager.FindByEmailAsync(email);

                if (user == null)
                {
                    // Brand-new account. We require full name + phone before creating it,
                    // because a rider cannot use the app without them. The first call
                    // (no profile data) asks the app to show the complete-profile screen.
                    if (string.IsNullOrWhiteSpace(model.FullName) || string.IsNullOrWhiteSpace(model.Phone))
                    {
                        return Response<LoginResponseDTO>.Success(new LoginResponseDTO
                        {
                            IsAuthenticated = false,
                            IsNewUser = true,
                            Name = payload.Name ?? "",
                            ProfilePicture = payload.Picture ?? "",
                        }, "مستخدم جديد، يرجى إكمال البيانات", 200);
                    }

                    var phone = NormalizePhone(model.Phone);
                    var phoneOwner = await _userManager.Users.FirstOrDefaultAsync(u => u.PhoneNumber == phone);
                    if (phoneOwner != null)
                        return Response<LoginResponseDTO>.Failure("رقم الهاتف مستخدم بالفعل في حساب آخر.", 409);

                    user = new ApplicationUser
                    {
                        UserName = email,
                        Email = email,
                        EmailConfirmed = true,
                        FullName = model.FullName.Trim(),
                        PhoneNumber = phone,
                        PhoneNumberConfirmed = false,
                        Gender = string.IsNullOrWhiteSpace(model.Gender) ? "Male" : model.Gender,
                        CreatedAt = DateTime.UtcNow,
                        ProfilePicture = string.IsNullOrWhiteSpace(model.ProfilePicture)
                            ? (payload.Picture ?? "")
                            : model.ProfilePicture,
                    };
                    var createResult = await _userManager.CreateAsync(user);
                    if (!createResult.Succeeded)
                    {
                        var err = string.Join(" ", createResult.Errors.Select(e => e.Description));
                        return Response<LoginResponseDTO>.Failure(string.IsNullOrWhiteSpace(err) ? "تعذّر إنشاء الحساب" : err, 400);
                    }
                    await _userManager.AddToRoleAsync(user, "Client");
                }

                // Captain accounts cannot sign in to the rider app.
                if (await _userManager.IsInRoleAsync(user, "Driver"))
                    return Response<LoginResponseDTO>.Failure(CaptainOnRiderMessage, 403);

                if (user.IsBlocked)
                    return Response<LoginResponseDTO>.Failure("تم تعطيل حسابك، يُرجى التواصل مع الدعم", 403);

                if (!string.IsNullOrEmpty(model.FCMToken))
                    await _notificationService.RegisterDeviceAsync(user.Id, model.FCMToken, model.DeviceType);

                return await BuildLoginResponse(user, false);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "GoogleTokenLogin error");
                return Response<LoginResponseDTO>.Failure("حدث خطأ، يرجى المحاولة لاحقًا.", 500);
            }
        }

        public async Task<Response<LoginResponseDTO>> GoogleTokenDriverAsync(GoogleTokenDriverDTO model)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(model?.IdToken))
                    return Response<LoginResponseDTO>.Failure("رمز Google مفقود", 400);

                GoogleJsonWebSignature.Payload payload;
                try
                {
                    payload = await GoogleJsonWebSignature.ValidateAsync(
                        model.IdToken,
                        new GoogleJsonWebSignature.ValidationSettings
                        {
                            Audience = GetGoogleAudiences()
                        });
                }
                catch (InvalidJwtException ex)
                {
                    Log.Warning(ex, "Invalid Google ID token (driver). Token aud was: {Aud}", ExtractAud(model.IdToken));
                    return Response<LoginResponseDTO>.Failure("رمز Google غير صالح أو منتهي الصلاحية.", 401);
                }

                var email = payload.Email?.ToLowerInvariant();
                if (string.IsNullOrWhiteSpace(email))
                    return Response<LoginResponseDTO>.Failure("لم يتم توفير البريد الإلكتروني من Google.", 400);

                var user = await _userManager.FindByEmailAsync(email);
                var roles = user != null ? await _userManager.GetRolesAsync(user) : new List<string>();

                if (user != null && roles.Contains("Driver"))
                {
                    if (user.IsBlocked)
                        return Response<LoginResponseDTO>.Failure("تم تعطيل حسابك، يُرجى التواصل مع الدعم", 403);

                    if (!string.IsNullOrEmpty(model.FCMToken))
                        await _notificationService.RegisterDeviceAsync(user.Id, model.FCMToken, model.DeviceType);

                    return await BuildLoginResponse(user, false);
                }

                // Existing account that isn't a captain → it's a rider, block it.
                if (user != null)
                    return Response<LoginResponseDTO>.Failure(RiderOnCaptainMessage, 403);

                // Brand-new account → prompt for captain signup data.
                if (string.IsNullOrWhiteSpace(model.FullName))
                    return Response<LoginResponseDTO>.Success(new LoginResponseDTO
                    {
                        IsAuthenticated = false,
                        IsNewUser = true,
                        Phone = null,
                    }, "كابتن جديد، يرجى إكمال بيانات التسجيل", 200);

                var scooterType = (ScooterType)model.ScooterType;
                if (scooterType == ScooterType.Gasoline && string.IsNullOrWhiteSpace(model.ScooterLicense))
                    return Response<LoginResponseDTO>.Failure("يرجى إدخال رخصة السكوتر (بنزين)", 400);

                if (user == null)
                {
                    user = new ApplicationUser
                    {
                        UserName = email,
                        Email = email,
                        EmailConfirmed = true,
                        FullName = model.FullName.Trim(),
                        Gender = string.IsNullOrWhiteSpace(model.Gender) ? "Male" : model.Gender,
                        NationalId = model.NationalId,
                        License = model.DriverLicense,
                        ProfilePicture = payload.Picture ?? "",
                        CreatedAt = DateTime.UtcNow,
                    };
                    var createResult = await _userManager.CreateAsync(user);
                    if (!createResult.Succeeded)
                    {
                        var err = string.Join(" ", createResult.Errors.Select(e => e.Description));
                        return Response<LoginResponseDTO>.Failure(string.IsNullOrWhiteSpace(err) ? "تعذّر إنشاء الحساب" : err, 400);
                    }
                }
                else
                {
                    if (string.IsNullOrWhiteSpace(user.NationalId)) user.NationalId = model.NationalId;
                    if (string.IsNullOrWhiteSpace(user.License)) user.License = model.DriverLicense;
                    await _userManager.UpdateAsync(user);
                }

                if (!await _userManager.IsInRoleAsync(user, "Driver"))
                    await _userManager.AddToRoleAsync(user, "Driver");

                await _unitOfWork.Scooters.AddAsync(new Scooter
                {
                    DriverId = user.Id,
                    License = model.ScooterLicense,
                    Type = scooterType,
                });
                await _unitOfWork.SaveAsync();

                if (!string.IsNullOrEmpty(model.FCMToken))
                    await _notificationService.RegisterDeviceAsync(user.Id, model.FCMToken, model.DeviceType);

                return await BuildLoginResponse(user, false);
            }
            catch (Exception ex)
            {
                Log.Error(ex, "GoogleTokenDriver error");
                return Response<LoginResponseDTO>.Failure("حدث خطأ، يرجى المحاولة لاحقًا.", 500);
            }
        }

        private static string NormalizePhone(string phone)
        {
            var p = phone.Trim().Replace(" ", "").Replace("-", "");
            if (p.StartsWith("+")) return p;
            if (p.StartsWith("00")) return "+" + p.Substring(2);
            if (p.StartsWith("0")) p = p.Substring(1);
            return "+20" + p;
        }

        private async Task<Response<LoginResponseDTO>> BuildLoginResponse(ApplicationUser user, bool isNewUser)
        {
            var token = await _jwtService.GenerateJwtToken(user);
            var refresh = _jwtService.CreateRefreshToken();
            user.RefreshTokens ??= new List<RefreshToken>();
            user.RefreshTokens.Add(refresh);
            await _userManager.UpdateAsync(user);
            var roles = await _userManager.GetRolesAsync(user);
            return Response<LoginResponseDTO>.Success(new LoginResponseDTO
            {
                UserId = user.Id,
                Name = user.FullName,
                Gender = user.Gender,
                IsAuthenticated = true,
                IsNewUser = isNewUser,
                Phone = user.PhoneNumber,
                Token = new JwtSecurityTokenHandler().WriteToken(token),
                RefreshToken = refresh.Token,
                RefreshTokenExpiration = refresh.ExpiresOn,
                Roles = roles.ToList(),
                ProfilePicture = user.ProfilePicture ?? "",
                NationalId = user.NationalId ?? "",
                License = user.License ?? "",
            }, "تم تسجيل الدخول بنجاح", 200);
        }

        private Task AddTokenToCookie(string refreshToken, DateTime refreshTokenExpiration)
        {
            // The dashboard SPA is served from a different origin than the API, so the
            // auth cookies must be SameSite=None+Secure to be sent on cross-site requests.
            // Both cookies below use the SAME policy (previously refreshToken was Strict,
            // which was inconsistent and silently dropped the cookie cross-site).
            var cookieOptions = new CookieOptions
            {
                HttpOnly = true,
                Expires = refreshTokenExpiration,
                SameSite = SameSiteMode.None,
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