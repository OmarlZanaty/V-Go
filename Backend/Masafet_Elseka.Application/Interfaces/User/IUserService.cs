using Masafet_Elseka.Application.Common.Pagination;
using Masafet_Elseka.Application.DTOs.BulkOperationResult;
using Masafet_Elseka.Application.DTOs.Rating;
using Masafet_Elseka.Application.DTOs.User;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.User
{
    public interface IUserService
    {
        public Task<Response<ICollection<UserListDTO>>> GetAllAsync(string role);
        public Task<Response<PaginationPagedResponse<UserDTO>>> GetAllForDashboard(PaginationRequest pagination, string role, string? search, string? gender);
        public Task<Response<UserDTO>> GetByIdAsync(string id);
        //public Task<Response<string>> RemoveUserAccount(string userId);
        //public Task<Response<string>> BlockUser(string userId);
        //public Task<Response<string>> UnBlockUser(string userId);
        public Task<Response<BulkOperationResult>> RemoveUsersBulk(List<string> userIds);
        public Task<Response<BulkOperationResult>> BlockUsers(IEnumerable<string> userId);
        public Task<Response<BulkOperationResult>> UnblockUsers(IEnumerable<string> userId);
        public Task<Response<string>> UpdateAsync(string userId, UserUpdateDTO model);
        public Task<Response<UpdateAllDTO>> UpdateUserForAdminAsync(string userId, UpdateAllDTO model);
        public Task<Response<int>> GetUsersNumber(string role);
        public Task<ApplicationUser> GetCurrentUserAsync();
    }
}
