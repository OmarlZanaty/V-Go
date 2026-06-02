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
        Task<ICollection<RatingResponseDTO>> GetCurrentUserTripRates();
    }
}
