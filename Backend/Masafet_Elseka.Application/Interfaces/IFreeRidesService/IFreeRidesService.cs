using Masafet_Elseka.Application.DTOs.FreeRides;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;

namespace Masafet_Elseka.Application.Interfaces.IFreeRidesService
{
    public interface IFreeRidesService
    {
        Task GrantToNewClientAsync(ApplicationUser user);
        Task<FreeRidesStatusDTO> GetStatusAsync(string userId);
        Task<bool> HasFreeRideAvailableAsync(string? userId);
        Task<Response<FreeRidesAdminSettingsDTO>> GetAdminSettingsAsync();
        Task<Response<FreeRidesAdminSettingsDTO>> UpdateAdminSettingsAsync(UpdateFreeRidesSettingsDTO dto);
    }
}
