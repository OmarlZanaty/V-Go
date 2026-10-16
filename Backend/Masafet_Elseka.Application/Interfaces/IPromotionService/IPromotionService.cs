using Masafet_Elseka.Application.DTOs.FreeRides;
using Masafet_Elseka.Application.DTOs.Promotions;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;

namespace Masafet_Elseka.Application.Interfaces.IPromotionService
{
    public interface IPromotionService
    {
        // Riders
        Task GrantSignUpOffersAsync(ApplicationUser user);
        // The best offer for this fare right now; changes nothing.
        Task<PromotionQuote?> BestOfferAsync(string? userId, decimal fare);
        // Same, for a trip being created inside the caller's transaction: joins
        // the rider to an all-riders offer when it is the one used.
        Task<PromotionQuote?> ApplyToNewTripAsync(string userId, decimal fare);
        Task<List<MyPromotionDTO>> GetMineAsync(string userId);
        Task<Response<MyPromotionDTO>> RedeemCodeAsync(string userId, string code);
        // Old apps read free rides from GET api/User/me/free-rides.
        Task<FreeRidesStatusDTO> GetFreeRidesStatusAsync(string userId);

        // Dashboard
        Task<List<PromotionAdminDTO>> GetAllAsync();
        Task<Response<PromotionAdminDTO>> CreateAsync(SavePromotionDTO dto);
        Task<Response<PromotionAdminDTO>> UpdateAsync(int id, SavePromotionDTO dto);
        Task<Response<PromotionAdminDTO>> SetActiveAsync(int id, bool active);
        Task<Response<string>> DeleteAsync(int id);
    }
}
