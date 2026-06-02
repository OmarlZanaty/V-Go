using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Payment.PayMob
{
    public class PaymobWebhookDTO
    {
        public string Type { get; set; }
        public PaymobTransactionDTO Obj { get; set; }
    }
}
