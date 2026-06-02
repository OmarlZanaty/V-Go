using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Payment.PayMob
{
    public class PaymobSourceDataDTO
    {
        public string Pan { get; set; }
        public string Type { get; set; }
        [JsonPropertyName("sub_type")]
        public string SubType { get; set; }
    }
}
