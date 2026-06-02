using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Payment
{
    public class PaymobIntentResponseDTO
    {
        [JsonPropertyName("intention_order_id")]
        public int IntentionOrderId { get; set; }

        [JsonPropertyName("id")]
        public string Id { get; set; }

        [JsonPropertyName("client_secret")]
        public string ClientSecret { get; set; }

        public string? PublicKey { get; set; }
    }
}
