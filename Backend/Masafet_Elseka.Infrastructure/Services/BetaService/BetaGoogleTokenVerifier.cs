using Google.Apis.Auth;
using Masafet_Elseka.Application.DTOs.Beta;
using Masafet_Elseka.Application.Interfaces.IBetaService;

namespace Masafet_Elseka.Infrastructure.Services.BetaService
{
    public class BetaGoogleTokenVerifier(BetaOptions options) : IBetaGoogleTokenVerifier
    {
        public async Task<BetaGoogleIdentity> VerifyAsync(string token, CancellationToken ct = default)
        {
            if (string.IsNullOrWhiteSpace(options.GoogleOAuthClientId))
                throw new BetaRequestException(503, "Google beta sign-in is not configured.");
            if (string.IsNullOrWhiteSpace(token))
                throw new BetaRequestException(401, "Invalid Google ID token.");
            try
            {
                var payload = await GoogleJsonWebSignature.ValidateAsync(token,
                    new GoogleJsonWebSignature.ValidationSettings
                    {
                        Audience = new[] { options.GoogleOAuthClientId }
                    }).WaitAsync(ct);
                if (string.IsNullOrWhiteSpace(payload.Subject) || string.IsNullOrWhiteSpace(payload.Email))
                    throw new BetaRequestException(401, "Invalid Google ID token.");
                if (!payload.EmailVerified)
                    throw new BetaRequestException(422, "Google email is not verified.");
                return new BetaGoogleIdentity(payload.Email, payload.Subject);
            }
            catch (InvalidJwtException)
            {
                throw new BetaRequestException(401, "Invalid Google ID token.");
            }
        }
    }
}
