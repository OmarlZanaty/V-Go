using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.ExternalDTOs.JWT
{
    public class NewRefreshTokenDTO
    {
        public string UserId { get; set; }
        public string Name { get; set; }
        public bool IsAuthenticated { get; set; }
        public string Token { get; set; }
        public string RefreshToken { get; set; }
        public List<string> Roles { get; set; }

    }
}
