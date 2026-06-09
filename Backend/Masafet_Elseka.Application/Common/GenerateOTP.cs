

using System.Security.Cryptography;
using System.Text;

namespace Masafet_Elseka.Application.Common
{
    static public class GenerateOTP
    {
        public static string Generateotp(int length = 6)
        {
            var otp = new StringBuilder(length);

            for (int i = 0; i < length; i++)
            {
                // Cryptographically secure, uniformly-distributed digit (0-9).
                // Replaces the shared System.Random, which is insecure and not
                // thread-safe (concurrent calls could produce correlated/duplicate codes).
                otp.Append(RandomNumberGenerator.GetInt32(0, 10));
            }
            return otp.ToString();
        }
    }
}
