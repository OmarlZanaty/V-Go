using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;

namespace Masafet_Elseka.Infrastructure.Services.AuthService;

public sealed class AppleTokenValidator
{
    private const string Issuer = "https://appleid.apple.com";
    private readonly HttpClient _httpClient;
    private readonly SemaphoreSlim _refreshLock = new(1, 1);
    private JsonWebKeySet? _keys;
    private DateTimeOffset _expiresAt;

    // A process-wide helper keeps the HTTP connection pool and 24-hour key cache.
    public static AppleTokenValidator Shared { get; } = new(new HttpClient());

    public AppleTokenValidator(HttpClient httpClient) => _httpClient = httpClient;

    public async Task<string> ValidateAsync(string token, string? extraAudiences = null)
    {
        var handler = new JwtSecurityTokenHandler { MapInboundClaims = false };
        if (string.IsNullOrWhiteSpace(token) || !handler.CanReadToken(token))
            throw new SecurityTokenException("Malformed Apple identity token.");

        JwtSecurityToken jwt;
        try { jwt = handler.ReadJwtToken(token); }
        catch (ArgumentException ex) { throw new SecurityTokenException("Malformed Apple identity token.", ex); }

        if (jwt.Header.Alg != SecurityAlgorithms.RsaSha256 || string.IsNullOrWhiteSpace(jwt.Header.Kid))
            throw new SecurityTokenException("Apple identity token must use RS256 and a key ID.");

        var keys = await GetKeysAsync();
        if (!keys.Keys.Any(key => key.Kid == jwt.Header.Kid))
            keys = await GetKeysAsync(keys); // Retry once for Apple key rotation.

        var audiences = new[] { "com.scooterapp.vgo", "com.scooterapp.vgo.vGoCaptain" }
            .Concat((extraAudiences ?? "").Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries));
        var principal = handler.ValidateToken(token, new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKeys = keys.GetSigningKeys().Where(key => key.KeyId == jwt.Header.Kid),
            TryAllIssuerSigningKeys = false,
            RequireSignedTokens = true,
            ValidAlgorithms = new[] { SecurityAlgorithms.RsaSha256 },
            ValidateIssuer = true,
            ValidIssuer = Issuer,
            ValidateAudience = true,
            ValidAudiences = audiences,
            ValidateLifetime = true,
            RequireExpirationTime = true,
            ClockSkew = TimeSpan.FromSeconds(30),
        }, out _);

        var email = principal.FindFirst("email")?.Value;
        if (string.IsNullOrWhiteSpace(email))
            throw new SecurityTokenException("Apple identity token has no email.");
        return email.ToLowerInvariant();
    }

    private async Task<JsonWebKeySet> GetKeysAsync(JsonWebKeySet? unknownKidKeys = null)
    {
        await _refreshLock.WaitAsync();
        try
        {
            // Concurrent refreshes reuse the newly fetched set.
            if (_keys == null || DateTimeOffset.UtcNow >= _expiresAt ||
                (unknownKidKeys != null && ReferenceEquals(_keys, unknownKidKeys)))
            {
                var json = await _httpClient.GetStringAsync(Issuer + "/auth/keys");
                _keys = new JsonWebKeySet(json);
                _expiresAt = DateTimeOffset.UtcNow.AddHours(24);
            }
            return _keys;
        }
        finally { _refreshLock.Release(); }
    }
}
