using Google.Apis.Auth;
using Masafet_Elseka.Application.DTOs.AuthDTOs;
using Masafet_Elseka.Application.ExternalInterfaces;
using Masafet_Elseka.Application.Interfaces.IAuthService;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.Models;
using Masafet_Elseka.Infrastructure.ExternalService.JWTService;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.IdentityModel.Tokens.Jwt;
using System.Text.Json;

namespace Masafet_Elseka.Infrastructure.ExternalService.GoogleAuth.GoogleAuthService
{
    public class GoogleAuthService : IGoogleAuthService
    {
        private readonly IConfiguration _configuration;
        private readonly IServiceScopeFactory _serviceScopeFactory;
        private readonly IAuthService _authService;
        private readonly IJWTService _jwtService;

        public GoogleAuthService(
            IConfiguration configuration,
            IServiceScopeFactory serviceScopeFactory,
            IAuthService authService,
            IJWTService jwtService)
        {
            _configuration = configuration;
            _serviceScopeFactory = serviceScopeFactory;
            _authService = authService;
            _jwtService = jwtService;
        }

        public async Task<Response<LoginResponseDTO>> GoogleLogin(string googleToken)
        {
            try
            {
                var payload = await VerifyGoogleToken(googleToken);
                if (payload == null)
                {
                    return Response<LoginResponseDTO>.Failure(
                        new LoginResponseDTO(), "Unauthorized User", 401);
                }

                using var scope = _serviceScopeFactory.CreateScope();
                var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
                var jwtService = scope.ServiceProvider.GetRequiredService<IJWTService>();

                var user = await userManager.FindByEmailAsync(payload.Email);

                if (user == null)
                {
                    return Response<LoginResponseDTO>.Failure(
                        new LoginResponseDTO(),
                        "User not exist, try to register first in app");
                }

                var userRoles = await userManager.GetRolesAsync(user);
                var jwtToken = await jwtService.GenerateJwtToken(user);
                var generatedToken = new JwtSecurityTokenHandler().WriteToken(jwtToken);

                var RefreshToken = jwtService.CreateRefreshToken();

                if (user.RefreshTokens == null)
                {
                    user.RefreshTokens = new List<RefreshToken>();
                }
                user.RefreshTokens!.Add(RefreshToken);

                await userManager.UpdateAsync(user);

                var userData = new LoginResponseDTO()
                {
                    UserId = user.Id,
                    Name = user.FullName,
                    ProfilePicture = user.ProfilePicture,
                    Gender = user.Gender,
                    License = user.License,
                    NationalId = user.NationalId,
                    Roles = userRoles.ToList(),
                    IsAuthenticated = true,
                    Token = generatedToken,
                    RefreshToken = RefreshToken.Token,
                    RefreshTokenExpiration = RefreshToken.ExpiresOn,
                };

                return Response<LoginResponseDTO>.Success(userData, "Login Successfully", 200);
            }
            catch (Exception ex)
            {
                return Response<LoginResponseDTO>.Failure(
                    new LoginResponseDTO(), $"Login failed: {ex.Message}", 500);
            }
        }

        private async Task<GoogleJsonWebSignature.Payload> VerifyGoogleToken(string token)
        {
            try
            {
                var settings = new GoogleJsonWebSignature.ValidationSettings()
                {
                    Audience = new[] { _configuration["GoogleAuth:ClientId"] }
                };

                return await GoogleJsonWebSignature.ValidateAsync(token, settings);
            }
            catch (Exception ex)
            {
                return null;
            }
        }

        // Web Login
        public async Task<string> ExchangeCodeForTokenAsync(string code)
        {
            using var client = new HttpClient();
            var redirectUri = _configuration["GoogleAuth:redirect_uri"];

            var values = new Dictionary<string, string>
            {
                { "code", code },
                { "client_id", _configuration["GoogleAuth:ClientId"] },
                { "client_secret", _configuration["GoogleAuth:ClientSecret"] },
                { "redirect_uri", redirectUri },
                { "grant_type", "authorization_code" }
            };

            var content = new FormUrlEncodedContent(values);
            var response = await client.PostAsync("https://oauth2.googleapis.com/token", content);
            var responseString = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                throw new Exception($"Google token exchange failed: {responseString}");
            }

            var tokenResponse = JsonSerializer.Deserialize<GoogleTokenResponse>(responseString);
            return tokenResponse?.IdToken;
        }

        public async Task<string> GetGoogleAuthUrl_Web()
        {
            var clientId = _configuration["GoogleAuth:ClientId"];
            var redirectUri = _configuration["GoogleAuth:redirect_uri"];

            if (string.IsNullOrEmpty(clientId))
            {
                return "ClientId is missing";
            }

            var queryParams = new Dictionary<string, string>
            {
                { "client_id", clientId },
                { "redirect_uri", redirectUri },
                { "response_type", "code" },
                { "scope", "openid email profile" },
                { "access_type", "offline" },
                { "prompt", "select_account" },
                { "state", Guid.NewGuid().ToString() }
            };

            var queryString = string.Join("&", queryParams
                .Select(kvp => $"{kvp.Key}={Uri.EscapeDataString(kvp.Value)}"));

            return $"{_configuration["GoogleAuth:googleAuthUrl"]}?{queryString}";
        }

        public async Task<Response<LoginResponseDTO>> ExchangeCodeForTokenMobileAsync(string code)
        {
            try
            {
                using var client = new HttpClient();

                var redirectUri = _configuration["GoogleAuth:redirect_uri_mobile"];


                var values = new Dictionary<string, string>
                {
                    { "code", code },
                    { "client_id", _configuration["GoogleAuth:ClientId"] },
                    { "client_secret", _configuration["GoogleAuth:ClientSecret"] },
                    { "redirect_uri", redirectUri },
                    { "grant_type", "authorization_code" }
                };

                var content = new FormUrlEncodedContent(values);
                var response = await client.PostAsync("https://oauth2.googleapis.com/token", content);
                var responseString = await response.Content.ReadAsStringAsync();


                if (!response.IsSuccessStatusCode)
                {
                    return Response<LoginResponseDTO>.Failure(
                        new LoginResponseDTO(),
                        $"Google token exchange failed: {responseString}",
                        400);
                }

                var tokenResponse = JsonSerializer.Deserialize<GoogleTokenResponse>(responseString);

                if (string.IsNullOrEmpty(tokenResponse?.IdToken))
                {
                    return Response<LoginResponseDTO>.Failure(
                        new LoginResponseDTO(),
                        "Failed to get ID token from Google",
                        400);
                }


                return await GoogleLogin(tokenResponse.IdToken);
            }
            catch (Exception ex)
            {
                return Response<LoginResponseDTO>.Failure(
                    new LoginResponseDTO(),
                    $"Mobile login failed: {ex.Message}",
                    500);
            }
        }

        // Generate Mobile Auth URL
        public string GetGoogleAuthUrl_Mobile()
        {
            var clientId = _configuration["GoogleAuth:ClientId"];
            var redirectUri = _configuration["GoogleAuth:redirect_uri_mobile"];

            if (string.IsNullOrEmpty(clientId))
            {
                throw new InvalidOperationException("ClientId is missing");
            }

            var queryParams = new Dictionary<string, string>
            {
                { "client_id", clientId },
                { "redirect_uri", redirectUri },
                { "response_type", "code" },
                { "scope", "openid email profile" },
                { "access_type", "offline" },
                { "prompt", "select_account" }
            };

            var queryString = string.Join("&", queryParams
                .Select(kvp => $"{kvp.Key}={Uri.EscapeDataString(kvp.Value)}"));

            return $"https://accounts.google.com/o/oauth2/v2/auth?{queryString}";
        }
    }
}