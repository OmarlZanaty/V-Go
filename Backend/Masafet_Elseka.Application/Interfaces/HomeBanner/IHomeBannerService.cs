using Masafet_Elseka.Application.DTOs.HomeBanner;
using Masafet_Elseka.Application.Response;
using Microsoft.AspNetCore.Http;

namespace Masafet_Elseka.Application.Interfaces.HomeBanner
{
    public interface IHomeBannerService
    {
        // Rider app: banners that are active and inside their date window, in order.
        Task<Response<List<ActiveBannerDTO>>> GetActiveAsync();
        Task RecordClickAsync(int id);

        // Dashboard.
        Task<Response<List<AdminBannerDTO>>> GetAllAsync();
        Task<Response<AdminBannerDTO>> CreateAsync(SaveBannerDTO dto, IFormFile? image, string actorUserId);
        Task<Response<AdminBannerDTO>> UpdateAsync(int id, SaveBannerDTO dto, IFormFile? image, string actorUserId);
        Task<Response<string>> DeleteAsync(int id, string actorUserId);
        Task<Response<List<AdminBannerDTO>>> ReorderAsync(List<int> orderedIds, string actorUserId);
    }
}
