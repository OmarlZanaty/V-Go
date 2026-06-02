using Masafet_Elseka.Application.ExternalDTOs.JWT;
using Masafet_Elseka.Application.Response;
using Masafet_Elseka.Domain.Entities;
using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.ExternalInterfaces
{
    public interface IJWTService
    {
        public Task<JwtSecurityToken> GenerateJwtToken(ApplicationUser user);
        public RefreshToken CreateRefreshToken();
        public Task<Response<NewRefreshTokenDTO>> GetNewRefreshToken(string token);
    }
}
