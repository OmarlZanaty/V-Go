using Masafet_Elseka.Domain.Entities;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.User
{
    public class UserListDTO
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string? ProfilePicture { get; set; }

    }
}
