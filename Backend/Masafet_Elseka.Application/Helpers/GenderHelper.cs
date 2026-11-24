namespace Masafet_Elseka.Application.Helpers
{
    /// <summary>
    /// Single source of truth for rider/captain gender. Stored values are exactly
    /// "Male" or "Female"; any app/admin spelling (Arabic, lowercase, ...) is normalized here.
    /// </summary>
    public static class GenderHelper
    {
        public const string Male = "Male";
        public const string Female = "Female";
        public const string InvalidMessage = "النوع مطلوب ويجب أن يكون ذكر أو أنثى (Male / Female).";

        /// <summary>Returns "Male", "Female" or null when the value is empty/unknown.</summary>
        public static string? Normalize(string? value)
        {
            if (string.IsNullOrWhiteSpace(value)) return null;
            var v = value.Trim().ToLowerInvariant();
            switch (v)
            {
                case "male": case "m": case "man": case "boy":
                case "ذكر": case "ذكَر": case "رجل": case "ولد":
                    return Male;
                case "female": case "f": case "woman": case "girl":
                case "أنثى": case "انثى": case "أنثي": case "انثي": case "بنت": case "سيدة": case "امرأة": case "امراة":
                    return Female;
                default:
                    return null;
            }
        }

        /// <summary>
        /// Signup resolution. Riders may omit gender (old iOS build, App Review 5.1.1(v)): they get the
        /// legacy default "Male" with confirmed=false so newer apps ask later. A supplied value must be
        /// valid (error = true otherwise) and is confirmed. Captains must always supply a valid gender.
        /// </summary>
        public static (string Gender, bool Confirmed, bool Error) ResolveForSignup(string? value, bool isRider)
        {
            if (string.IsNullOrWhiteSpace(value))
                return isRider ? (Male, false, false) : (Male, false, true);
            var n = Normalize(value);
            return n == null ? (Male, false, true) : (n, true, false);
        }

        /// <summary>
        /// Dispatch rule: a trip and a captain are compatible only when they have the same gender.
        /// An empty/unknown value is treated as "Male", which is what every legacy account was
        /// defaulted to, so old users keep working exactly as before.
        /// </summary>
        public static bool IsCompatible(string? clientGender, string? driverGender)
            => (Normalize(clientGender) ?? Male) == (Normalize(driverGender) ?? Male);

        /// <summary>True when both normalize to the same known gender.</summary>
        public static bool SameGender(string? a, string? b)
        {
            var na = Normalize(a);
            var nb = Normalize(b);
            return na != null && na == nb;
        }
    }
}
