using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Payment.PayMob
{
    public class PaymobTransactionDTO
    {
        public int Id { get; set; }
        public bool Pending { get; set; }
        [JsonPropertyName("amount_cents")]
        public decimal AmountCents { get; set; }
        public bool Success { get; set; }
        [JsonPropertyName("is_auth")]
        public bool IsAuth { get; set; }
        [JsonPropertyName("is_capture")]
        public bool IsCapture { get; set; }
        [JsonPropertyName("is_standalone_payment")]
        public bool IsStandalonePayment { get; set; }
        [JsonPropertyName("is_voided")]
        public bool IsVoided { get; set; }
        [JsonPropertyName("is_refunded")]
        public bool IsRefunded { get; set; }
        [JsonPropertyName("is_3d_secure")]
        public bool Is3dSecure { get; set; }
        [JsonPropertyName("integration_id")]
        public int IntegrationId { get; set; }
        [JsonPropertyName("profile_id")]
        public int ProfileId { get; set; }
        public PaymobOrderDTO Order { get; set; }
        [JsonPropertyName("created_at")]
        public string CreatedAt { get; set; }
        public string Currency { get; set; }
        [JsonPropertyName("error_occured")]
        public bool ErrorOccured { get; set; }
        [JsonPropertyName("has_parent_transaction")]
        public bool HasParentTransaction { get; set; }
        public int Owner { get; set; }
        [JsonPropertyName("source_data")]
        public PaymobSourceDataDTO SourceData { get; set; }
    }
}
