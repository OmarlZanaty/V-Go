using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Domain.Enums
{
    public enum PaymentStatus
    {
        Pending = 1,
        Paid,
        Failed,

        // Visa pre-authorization (Auth & Capture) lifecycle. Appended after the
        // legacy values so existing rows (Pending/Paid/Failed) keep their ints.
        PreAuthInitiated,   // 4 - intention created, awaiting the auth webhook
        PreAuthSuccess,     // 5 - funds held on the card, ride may proceed
        PreAuthFailed,      // 6 - card declined at pre-auth
        Captured,           // 7 - held amount actually charged (ride completed)
        CaptureFailed,      // 8 - capture call failed at Paymob
        Voided,             // 9 - hold released (ride cancelled before capture)
        VoidFailed          // 10 - void call failed at Paymob
    }
}
