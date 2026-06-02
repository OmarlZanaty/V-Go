using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.AuthState;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.GoogleAuthService;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.GoogleAuthManagerService
{
    public class GoogleAuthManager : IGoogleAuthManager
    {
        private readonly IConfiguration _configuration;
        private readonly IAuthStateService _authStateService;
        private readonly IGoogleAuthService _googleAuthService;

        public GoogleAuthManager(
            IConfiguration configuration,
            IAuthStateService authStateService,
            IGoogleAuthService googleAuthService)
        {
            _configuration = configuration;
            _authStateService = authStateService;
            _googleAuthService = googleAuthService;
        }

        public async Task<GoogleAuthUrlResponse> GenerateMobileAuthUrlAsync()
        {
            try
            {
                var clientId = _configuration["GoogleAuth:ClientId"];
                var redirectUri = _configuration["GoogleAuth:redirect_uri_mobile"];

                if (string.IsNullOrEmpty(clientId))
                {
                    return new GoogleAuthUrlResponse
                    {
                        Success = false,
                        Message = "ClientId is missing"
                    };
                }

                var state = Guid.NewGuid().ToString();
                _authStateService.AddState(state);

                var authUrl = BuildGoogleAuthUrl(clientId, redirectUri, state);

                return new GoogleAuthUrlResponse
                {
                    Success = true,
                    AuthUrl = authUrl,
                    State = state,
                    RedirectUri = redirectUri
                };
            }
            catch (Exception ex)
            {
                return new GoogleAuthUrlResponse
                {
                    Success = false,
                    Message = ex.Message
                };
            }
        }

        public async Task<AuthStatusResponse> ProcessMobileCallbackAsync(string code, string state)
        {
            try
            {
                if (string.IsNullOrEmpty(state))
                {
                    return new AuthStatusResponse
                    {
                        Success = false,
                        Status = "invalid",
                        Message = "Missing state parameter"
                    };
                }

                var existingState = _authStateService.GetState(state);
                if (existingState == null)
                {
                    return new AuthStatusResponse
                    {
                        Success = false,
                        Status = "invalid",
                        Message = "Session expired or invalid"
                    };
                }
                if (string.IsNullOrEmpty(code))
                {
                    existingState.Status = "failed";
                    return new AuthStatusResponse
                    {
                        Success = false,
                        Status = "failed",
                        Message = "No authorization code received"
                    };
                }

                bool success = await _authStateService.CompleteState(state, code);

                if (success)
                {
                    return new AuthStatusResponse
                    {
                        Success = true,
                        Status = "completed",
                        Message = "Authentication completed successfully"
                    };
                }
                else
                {
                    return new AuthStatusResponse
                    {
                        Success = false,
                        Status = "failed",
                        Message = "Please register your account first,\n You can return to the app and register."
                    };
                }
            }
            catch (Exception ex)
            {
                return new AuthStatusResponse
                {
                    Success = false,
                    Status = "error",
                    Message = ex.Message
                };
            }
        }

        public async Task<AuthStatusResponse> CheckAuthStatusAsync(string state)
        {
            try
            {
                var authState = _authStateService.GetState(state);

                if (authState == null)
                {
                    return new AuthStatusResponse
                    {
                        Success = false,
                        Status = "not_found",
                        Message = "State not found or expired"
                    };
                }

                if (authState.Status == "completed" && authState.UserData != null)
                {
                    authState.IsUsed = true;

                    return new AuthStatusResponse
                    {
                        Success = true,
                        Status = "completed",
                        User = new
                        {
                            userId = authState.UserData.UserId,
                            name = authState.UserData.Name,
                            gender=authState.UserData.Gender,
                            profilePicture = authState.UserData.ProfilePicture,
                            roles = authState.UserData.Roles,
                            isAuthenticated = authState.UserData.IsAuthenticated,
                            token= authState.UserData.Token,
                            refreshToken=authState.UserData.RefreshToken,
                            refreshTokenExpiration=authState.UserData.RefreshTokenExpiration,
                            },

                        Message = "Login successful"
                    };
                }
                else if (authState.Status == "completed")
                {
                    return new AuthStatusResponse
                    {
                        Success = false,
                        Status = "failed",
                        Message = "User data not available"
                    };
                }
                else
                {
                    return new AuthStatusResponse
                    {
                        Success = true,
                        Status = authState.Status,
                        Message = authState.Status == "pending"
                            ? "Waiting for authentication"
                            : "Authentication failed"
                    };
                }
            }
            catch (Exception ex)
            {
                return new AuthStatusResponse
                {
                    Success = false,
                    Status = "error",
                    Message = ex.Message
                };
            }
        }

        private string BuildGoogleAuthUrl(string clientId, string redirectUri, string state)
        {
            var queryParams = new Dictionary<string, string>
        {
            { "client_id", clientId },
            { "redirect_uri", redirectUri },
            { "response_type", "code" },
            { "scope", "openid email profile" },
            { "access_type", "offline" },
            { "prompt", "select_account" },
            { "state", state }
        };

            var queryString = string.Join("&", queryParams
                .Select(kvp => $"{kvp.Key}={Uri.EscapeDataString(kvp.Value)}"));

            return $"https://accounts.google.com/o/oauth2/v2/auth?{queryString}";
        }
    }
}
