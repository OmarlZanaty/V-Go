using Masafet_Elseka.Application.DTOs.Rating;
using Masafet_Elseka.Application.Interfaces.User;
using Masafet_Elseka.Application.Response;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.Interfaces.IRatingService
{
    public interface IRatingService
    {
        Task<Response<RatingResponseDTO>> AddRateAsync(RatingDTO rate);
        Task<Response<ICollection<RatingResponseDTO>>> GetUserRates(string userId);
        Task<decimal> GetAverageRate(string userId);
        // Batched average rating for many users in ONE query (avoids the per-row
        // N+1 + sync-over-async that exhausted threads/connections under load).
        Task<Dictionary<string, decimal>> GetAverageRatesFor(IEnumerable<string> userIds);
        Task<ICollection<RatingResponseDTO>> GetCurrentUserTripRates();
    }
}
