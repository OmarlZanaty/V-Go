using CloudinaryDotNet.Actions;
using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.BulkOperationResult;
using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.DTOs.RateDTOs;
using Masafet_Elseka.Application.DTOs.Rating;
using Masafet_Elseka.Application.DTOs.Trip;
using Masafet_Elseka.Application.DTOs.User;
using Masafet_Elseka.Application.ExternalInterfaces.ICloudinaryService;
using Masafet_Elseka.Application.Interfaces.IDriverService;
using Masafet_Elseka.Application.Interfaces.IRatingService;
using Masafet_Elseka.Application.Interfaces.ITripService;
using Masafet_Elseka.Application.Interfaces.User;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Services.UserService
{
    public class UserService : IUserService
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly RoleManager<IdentityRole> _roleManager;
        private readonly ICloudinaryService _cloudinaryService;
        private readonly Context _context;
        private readonly ITripService _tripService;
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly IDriverService _driverService;
        private readonly IRatingService _ratingService;

        public UserService(UserManager<ApplicationUser> userManager, RoleManager<IdentityRole> roleManager, ICloudinaryService cloudinaryService
            , Context context, ITripService tripService, IHttpContextAccessor httpContextAccessor, IDriverService driverService, IRatingService ratingService)
        {
            _userManager = userManager;
            _roleManager = roleManager;
            _cloudinaryService = cloudinaryService;
            _context = context;
            _tripService = tripService;
            _httpContextAccessor = httpContextAccessor;
            _driverService = driverService;
            _ratingService = ratingService;
        }

        public async Task<ApplicationUser> GetCurrentUserAsync()
        {
            ClaimsPrincipal currentUser = _httpContextAccessor.HttpContext.User;
            return await _userManager.GetUserAsync(currentUser);
        }

        public async Task<Response<ICollection<UserListDTO>>> GetAllAsync(string role)
        {
            try
            {
                var users = await _userManager.GetUsersInRoleAsync(role);
                if (users == null || !users.Any())
                {
                    return Response<ICollection<UserListDTO>>.Failure("لا يوجد مستخدمين بهذا الدور", 404);
                }

                var userList = users.Select(user => new UserListDTO
                {
                    Id = user.Id,
                    Name = user.FullName,
                    ProfilePicture = user.ProfilePicture
                }).ToList();

                return Response<ICollection<UserListDTO>>.Success(userList, "تم جلب المستخدمين بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<ICollection<UserListDTO>>.Failure($"حدث خطأ أثناء جلب المستخدمين: {ex.Message}", 500);
            }
        }

        public async Task<Response<PaginationPagedResponse<UserDTO>>> GetAllForDashboard(PaginationRequest pagination, string role, string? search, string? gender)
        {
            try
            {
                var query = _context.Users.AsQueryable();

                if (!string.IsNullOrEmpty(search))
                {
                    query = query.Where(u => u.FullName.Contains(search) || u.PhoneNumber.Contains(search) || u.NationalId.Contains(search));
                }
                if (!string.IsNullOrEmpty(gender))
                {
                    query = query.Where(u => u.Gender == gender);
                }
                var usersList = await query.ToListAsync();

                var filteredUsers = new List<ApplicationUser>();
                foreach (var user in usersList)
                {
                    if (await _userManager.IsInRoleAsync(user, role))
                        filteredUsers.Add(user);
                }

                var totalCount = filteredUsers.Count;

                if (!query.Any())
                {
                    return Response<PaginationPagedResponse<UserDTO>>.Success(new PaginationPagedResponse<UserDTO>(
                        new List<UserDTO>(), totalCount, pagination.PageNumber, pagination.PageSize), "لا يوجد مستخدمين بهذا الدور", 200);
                }

                var users = filteredUsers
                    .Skip((pagination.PageNumber - 1) * pagination.PageSize)
                    .Take(pagination.PageSize)
                    .ToList();
                var userDtos = new List<UserDTO>();
                foreach (var user in users)
                {
                    var userDto = new UserDTO
                    {
                        Id = user.Id,
                        Name = user.FullName,
                        PhoneNumber = user.PhoneNumber,
                        Email = user.Email,
                        Gender = user.Gender,
                        NationalId = user.NationalId,
                        ProfilePicture = user.ProfilePicture,
                        Roles = await _userManager.GetRolesAsync(user),
                        IsBlocked = user.IsBlocked,
                        Rate = await _ratingService.GetAverageRate(user.Id),
                        TripCount = await _tripService.GetTripCountForUser(user.Id)
                    };
                    userDtos.Add(userDto);
                }

                var pagedResponse = new PaginationPagedResponse<UserDTO>(userDtos, totalCount, pagination.PageNumber, pagination.PageSize);
                return Response<PaginationPagedResponse<UserDTO>>.Success(pagedResponse, "تم جلب المستخدمين بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<PaginationPagedResponse<UserDTO>>.Failure($"حدث خطأ أثناء جلب المستخدمين: {ex.Message}", 500);
            }
        }

        public async Task<Response<UserDTO>> GetByIdAsync(string id)
        {
            try
            {
                var user = await _userManager.FindByIdAsync(id);
                if (user == null)
                {
                    return Response<UserDTO>.Failure("المستخدم غير موجود", 404);
                }

                var userDto = new UserDTO
                {
                    Id = user.Id,
                    Name = user.FullName,
                    PhoneNumber = user.PhoneNumber,
                    Gender = user.Gender,
                    NationalId = user.NationalId,
                    ProfilePicture = user.ProfilePicture,
                    Roles=await _userManager.GetRolesAsync(user),
                    Email=user.Email,
                    IsBlocked=user.IsBlocked,
                    Rate = await _ratingService.GetAverageRate(id)
                };

                if (await _userManager.IsInRoleAsync(user, "Client"))
                {
                    var rates = await _context.Rates
                        .Where(r => r.ToUserId == id)
                        .Select(r => new UserRateDTO
                        {
                            Score = r.Score,
                            Comment = r.Comment,
                        }).ToListAsync();

                    userDto.TripCount =await _tripService.GetTripCountForUser(id) ;
                }

                return Response<UserDTO>.Success(userDto, "تم جلب بيانات المستخدم بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<UserDTO>.Failure($"حدث خطأ أثناء جلب بيانات المستخدم: {ex.Message}", 500);
            }
        }
        public async Task<Response<BulkOperationResult>> RemoveUsersBulk(List<string> userIds)
        {
            try
            {
                if (userIds == null || userIds.Count == 0)
                    return Response<BulkOperationResult>.Failure("لا يوجد مستخدمين للحذف", 400);

                var normalizedUserIds = userIds.Select(u => u.Trim().ToLower()).ToHashSet();

                var users = await _context.Users
                    .Where(u => normalizedUserIds.Contains(u.Id.ToLower()))
                    .ToListAsync();

                var result = new BulkOperationResult();

                foreach (var user in users)
                {
                    user.IsDeleted = true;
                    user.LockoutEnabled = true;
                    user.LockoutEnd = DateTimeOffset.MaxValue;
                    result.SucceededIds.Add(user.Id);
                }

                var foundIdsLower = users.Select(u => u.Id.ToLower()).ToHashSet();
                var notFoundIds = normalizedUserIds.Except(foundIdsLower).ToList();
                result.NotFoundIds.AddRange(notFoundIds);

                if (users.Any())
                {
                    _context.Users.UpdateRange(users);
                    await _context.SaveChangesAsync();
                }

                return Response<BulkOperationResult>.Success(result, "تمت العملية بنجاح", 200);
            }
            catch (Exception ex)
            {
                var errorResult = new BulkOperationResult();
                return Response<BulkOperationResult>.Failure(errorResult,"حدث خطأ أثناء محاولة حذف الحسابات", 500);
            }
        }


        public async Task<Response<BulkOperationResult>> BlockUsers(IEnumerable<string> userIds)
        {
            if (userIds == null || !userIds.Any())
                return Response<BulkOperationResult>.Failure(null,"لم يتم تمرير أي معرفات مستخدمين", 400);

            var result = new BulkOperationResult();

            foreach (var id in userIds)
            {
                try
                {
                    var user = await _userManager.FindByIdAsync(id);
                    if (user == null)
                    {
                        result.NotFoundIds.Add(id);
                        continue;
                    }
                    if (user.IsBlocked)
                    {
                        result.SucceededIds.Add(id);
                        continue;
                    }

                    user.IsBlocked = true;
                    var update = await _userManager.UpdateAsync(user);
                    if (update.Succeeded)
                    {
                        result.SucceededIds.Add(id);
                    }
                    else
                    {
                        var errors = update.Errors?.Select(e => e.Description) ?? Enumerable.Empty<string>();
                        result.Failed.Add(new FailedItem { Id = id, Reason = string.Join("; ", errors) });
                    }
                }
                catch (Exception ex)
                {
                    result.Failed.Add(new FailedItem { Id = id, Reason = $"Exception: {ex.Message}" });
                }
            }

            if (!result.Failed.Any())
                return Response<BulkOperationResult>.Success(result, $"تم حظر {result.SuccessCount} مستخدم(ين) بنجاح", 200);

            return Response<BulkOperationResult>.Failure(result, $"انتهت العملية — نجاح: {result.SuccessCount}, فشل: {result.FailedCount}",207);
        }

        public async Task<Response<BulkOperationResult>> UnblockUsers(IEnumerable<string> userIds)
        {
            if (userIds == null || !userIds.Any())
                return Response<BulkOperationResult>.Failure(null,"لم يتم تمرير أي معرفات مستخدمين", 400);

            var result = new BulkOperationResult();

            foreach (var id in userIds)
            {
                try
                {
                    var user = await _userManager.FindByIdAsync(id);
                    if (user == null)
                    {
                        result.NotFoundIds.Add(id);
                        continue;
                    }

                    if (!user.IsBlocked)
                    {
                        result.SucceededIds.Add(id);
                        continue;
                    }

                    user.IsBlocked = false;
                    var update = await _userManager.UpdateAsync(user);
                    if (update.Succeeded)
                    {
                        result.SucceededIds.Add(id);
                    }
                    else
                    {
                        var errors = update.Errors?.Select(e => e.Description) ?? Enumerable.Empty<string>();
                        result.Failed.Add(new FailedItem { Id = id, Reason = string.Join("; ", errors) });
                    }
                }
                catch (Exception ex)
                {
                    result.Failed.Add(new FailedItem { Id = id, Reason = $"Exception: {ex.Message}" });
                }
            }

            if (!result.Failed.Any())
                return Response<BulkOperationResult>.Success(result, $"تم فك حظر {result.SuccessCount} مستخدم(ين) بنجاح", 200);

            return Response<BulkOperationResult>.Failure(result,$"انتهت العملية — نجاح: {result.SuccessCount}, فشل: {result.FailedCount}",207);
        }


        public async Task<Response<string>> UpdateAsync(string userId, UserUpdateDTO model)
        {
            try
            {
                var user = await _userManager.FindByIdAsync(userId);
                if (user is null)
                {
                    return Response<string>.Failure("المستخدم غير موجود", 404);
                }

                string? imgPath = null;
                if (model.ProfilePicture is not null)
                {
                    var image = await _cloudinaryService.UploadFileAsync(model.ProfilePicture, "ProfilePictures");
                    imgPath = image.Url;
                }

                user.FullName = model.Name ?? user.FullName;
                user.PhoneNumber = model.PhoneNumber ?? user.PhoneNumber;
                user.Gender = model.Gender ?? user.Gender;
                user.ProfilePicture = imgPath ?? user.ProfilePicture;

                var result = await _userManager.UpdateAsync(user);
                if (!result.Succeeded)
                {
                    return Response<string>.Failure("حدث خطأ اثناء تحديث البيانات", 400);
                }

                return Response<string>.Success("تم تحديث البيانات بنجاح", "تم تحديث البيانات بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<string>.Failure($"حدث خطأ اثناء تحديث البيانات: {ex.Message}", 500);
            }
        }

        public async Task<Response<int>> GetUsersNumber(string role)
        {
            try
            {
                var users = await _userManager.GetUsersInRoleAsync(role);
                if (users == null)
                {
                    return Response<int>.Failure("لا يوجد مستخدمين بهذا الدور", 404);
                }
                if (!users.Any())
                {
                    return Response<int>.Success(0, "لا يوجد مستخدمين بهذا الدور", 201);
                }

                return Response<int>.Success(users.Count, "تم جلب عدد المستخدمين بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<int>.Failure($"حدث خطأ أثناء جلب عدد المستخدمين: {ex.Message}", 500);
            }
        }

        public async Task<Response<UpdateAllDTO>> UpdateUserForAdminAsync(string userId, UpdateAllDTO model)
        {
            try
            {
                var user = await _context.Users.Include(d => d.Scooter)
                    .FirstOrDefaultAsync(d => d.Id == userId);
                if (user is null)
                {
                    return Response<UpdateAllDTO>.Failure("المستخدم غير موجود", 404);
                }

                string? imgPath = null;
                if (model.ProfilePicture is not null)
                {
                    var image = await _cloudinaryService.UploadFileAsync(model.ProfilePicture, "ProfilePictures");
                    imgPath = image.Url;
                }

                user.FullName = model.Name ?? user.FullName;
                user.PhoneNumber = model.PhoneNumber ?? user.PhoneNumber;
                user.Gender = model.Gender ?? user.Gender;
                user.NationalId = model.NationalId ?? user.NationalId;
                user.License = model.License ?? user.License;
                user.ProfilePicture = imgPath ?? user.ProfilePicture;
                model.ProfilePicturePath = imgPath ?? user.ProfilePicture;
                if (model.ScooterLicense!=null || model.ScooterType != null)
                {
                    DriverUpdateDTO scooterData = new()
                    {
                        ScooterLicense = model.ScooterLicense,
                        ScooterType = model.ScooterType,
                    };
                    var scooterResult = await _driverService.CheckScooterData(user, scooterData);
                    if (!scooterResult)
                    {
                        return Response<UpdateAllDTO>.Failure("يجب ادخال رخصة السكوتر", 400);
                    }
                }

                var result = await _userManager.UpdateAsync(user);
                if (!result.Succeeded)
                {
                    return Response<UpdateAllDTO>.Failure("حدث خطأ اثناء تحديث البيانات", 400);
                }

                return Response<UpdateAllDTO>.Success(model, "تم تحديث البيانات بنجاح", 200);
            }
            catch (Exception ex)
            {
                return Response<UpdateAllDTO>.Failure($"حدث خطأ اثناء تحديث البيانات: {ex.Message}", 500);
            }
        }

    }
}