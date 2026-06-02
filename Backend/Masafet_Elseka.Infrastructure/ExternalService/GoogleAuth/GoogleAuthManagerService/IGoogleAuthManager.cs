using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.GoogleAuthManagerService
{
    public interface IGoogleAuthManager
    {
        Task<GoogleAuthUrlResponse> GenerateMobileAuthUrlAsync();
        Task<AuthStatusResponse> ProcessMobileCallbackAsync(string code, string state);
        Task<AuthStatusResponse> CheckAuthStatusAsync(string state);
    }
}
