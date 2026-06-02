using Masafet_Elseka.Application.ExternalDTOs.JWT;
using Masafet_Elseka.Application.ExternalInterfaces;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.JWTService
{
    public class JWTService : IJWTService
    {
        private readonly IConfiguration _configuration;
        private readonly UserManager<ApplicationUser> _userManager;

        public JWTService(IConfiguration configuration, UserManager<ApplicationUser> userManager)
        {
            _configuration = configuration;
            _userManager = userManager;
        }

        public async Task<JwtSecurityToken> GenerateJwtToken(ApplicationUser user)
        {
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.Name, user.FullName),
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(JwtRegisteredClaimNames.Sub, user.UserName),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
                new Claim(JwtRegisteredClaimNames.Email,user.Email),
                new Claim("uid", user.Id)
            };

            var roles = await _userManager.GetRolesAsync(user);
            foreach (var role in roles)
            {
                claims.Add(new Claim(ClaimTypes.Role, role));
            }

            var jwtKey = _configuration["JWT:Key"] ?? throw new InvalidOperationException("JWT Key not found in Config");
            SecurityKey key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));
            SigningCredentials signingCred = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
            var Token = new JwtSecurityToken(
                issuer: _configuration["JWT:Issuer"],
                audience: _configuration["JWT:Audience"],
                claims: claims,
                signingCredentials: signingCred,
                expires: DateTime.UtcNow.AddDays(1)
            );

            return Token;
        }

        public async Task<Response<NewRefreshTokenDTO>> GetNewRefreshToken(string token)
        {
            var user = await _userManager.Users.FirstOrDefaultAsync(u => u.RefreshTokens!.Any(t => t.Token == token));
            if(user == null)
            {
                return Response<NewRefreshTokenDTO>.Failure("هذا المستخدم غير مصرح له، يرجى تسجيل الدخول اولا.", 401);
            }

            var refreshToken = user.RefreshTokens?.FirstOrDefault(t => t.Token == token);
            if (refreshToken == null || !refreshToken.IsActive)
            {
                return Response<NewRefreshTokenDTO>.Failure(new NewRefreshTokenDTO
                {
                    UserId= user.Id,
                    Name = user.FullName,
                    IsAuthenticated = false,
                    Token = string.Empty,
                    RefreshToken = string.Empty,
                    Roles=new List<string>()
                },"رمز التحديث غير نشط أو منتهي الصلاحية.", 401);
            }

            refreshToken.RevokedOn = DateTime.Now.ToEgyptTime();
            var newRefreshToken = CreateRefreshToken();
            user.RefreshTokens!.Add(newRefreshToken);
            await _userManager.UpdateAsync(user);
            var Roles = await _userManager.GetRolesAsync(user);
            var jwtToken = await GenerateJwtToken(user);

            return Response<NewRefreshTokenDTO>.Success(new NewRefreshTokenDTO
            {
                UserId = user.Id,
                Name = user.FullName,
                IsAuthenticated = true,
                Token = new JwtSecurityTokenHandler().WriteToken(jwtToken),
                RefreshToken = newRefreshToken.Token,
                Roles = Roles.ToList(),
            }, "تم إنشاء رمز التحديث الجديد بنجاح.", 200);

        }

        public RefreshToken CreateRefreshToken()
        {
            var randomNumber = new byte[32];
            RandomNumberGenerator.Fill(randomNumber);

            return new RefreshToken
            {
                Token = Convert.ToBase64String(randomNumber),
                ExpiresOn = DateTime.Now.ToEgyptTime().AddDays(7),
                CreatedOn = DateTime.Now.ToEgyptTime()
            };
        }
    }
}