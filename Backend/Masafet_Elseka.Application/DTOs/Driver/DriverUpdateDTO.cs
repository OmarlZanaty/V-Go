using Masafet_Elseka.Domain.Enums;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Driver
{
    public class DriverUpdateDTO
    {
        public ScooterType? ScooterType { get; set; }
        public string? ScooterLicense { get; set; }
    }
}
