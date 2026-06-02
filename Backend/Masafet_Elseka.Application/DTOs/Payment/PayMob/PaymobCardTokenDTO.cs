using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Payment.PayMob
{
    public class PaymobCardTokenDTO
    {
        public int Id { get; set; }
        public string Token { get; set; }

        [JsonPropertyName("masked_pan")]
        public string MaskedPan { get; set; }

        [JsonPropertyName("merchant_id")]
        public long MerchantId { get; set; }

        [JsonPropertyName("card_subtype")]
        public string CardSubtype { get; set; }

        [JsonPropertyName("order_id")]
        public long OrderId { get; set; }

        public string Email { get; set; }

        [JsonPropertyName("created_at")]
        public DateTime CreatedAt { get; set; }
    }
}
