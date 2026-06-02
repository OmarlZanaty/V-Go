

using System.Text;

namespace Masafet_Elseka.Application.Common
{
    static public class GenerateOTP
    {
        private static Random _random = new Random();
        public static string Generateotp(int length = 6)
        {
            var otp = new StringBuilder();

            for (int i = 0; i < length; i++)
            {
                otp.Append(_random.Next(0, 10));
            }
            return otp.ToString();
        }
    }
}
