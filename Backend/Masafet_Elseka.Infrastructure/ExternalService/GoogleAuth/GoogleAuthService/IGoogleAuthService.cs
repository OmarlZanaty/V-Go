using Google.Apis.Auth;
using Masafet_Elseka.Application.DTOs.AuthDTOs;
using Masafet_Elseka.Application.Response;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.GoogleAuthService
{
    public interface IGoogleAuthService
    {
        
        Task<string> ExchangeCodeForTokenAsync(string code); 
        Task<Response<LoginResponseDTO>> GoogleLogin(string googleToken);
        Task<string> GetGoogleAuthUrl_Web();
        Task<Response<LoginResponseDTO>> ExchangeCodeForTokenMobileAsync(string code);
        string GetGoogleAuthUrl_Mobile();
    }
}
