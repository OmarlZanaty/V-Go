using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.Json;
using Masafet_Elseka.Infrastructure.Services.AuthService;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace Masafet_Elseka.Tests;

public sealed class AppleTokenValidatorTests : IDisposable
{
    private readonly RSA _rsa = RSA.Create(2048);
    private readonly FakeJwksHandler _handler = new();
    private readonly HttpClient _client;
    private readonly AppleTokenValidator _validator;

    public AppleTokenValidatorTests()
    {
        _handler.Jwks = Jwks("original");
        _client = new HttpClient(_handler);
        _validator = new AppleTokenValidator(_client);
    }

    [Theory]
    [InlineData("com.scooterapp.vgo")]
    [InlineData("com.scooterapp.vgo.vGoCaptain")]
    public async Task Valid_token_accepts_both_apps_and_lowercases_relay_email(string audience)
    {
        Assert.Equal("user@privaterelay.appleid.com", await _validator.ValidateAsync(Token(audience: audience)));
        Assert.Equal(1, _handler.Requests);
    }

    [Fact]
    public async Task Bad_issuer_is_rejected() =>
        await Assert.ThrowsAsync<SecurityTokenInvalidIssuerException>(() => _validator.ValidateAsync(Token(issuer: "https://attacker.example")));

    [Fact]
    public async Task Bad_audience_is_rejected() =>
        await Assert.ThrowsAsync<SecurityTokenInvalidAudienceException>(() => _validator.ValidateAsync(Token(audience: "another.app")));

    [Fact]
    public async Task Expired_token_is_rejected() =>
        await Assert.ThrowsAsync<SecurityTokenExpiredException>(() => _validator.ValidateAsync(Token(expires: DateTime.UtcNow.AddMinutes(-2))));

    [Fact]
    public async Task Missing_email_is_rejected() =>
        await Assert.ThrowsAsync<SecurityTokenException>(() => _validator.ValidateAsync(Token(email: null)));

    [Fact]
    public async Task Optional_comma_separated_audiences_are_trimmed_and_accepted()
    {
        Assert.Equal("user@privaterelay.appleid.com",
            await _validator.ValidateAsync(Token(audience: "extra.app"), " , extra.app, second.app ,"));
    }

    [Fact]
    public async Task Known_key_reuses_cached_jwks()
    {
        await _validator.ValidateAsync(Token());
        await _validator.ValidateAsync(Token());
        Assert.Equal(1, _handler.Requests);
    }

    [Fact]
    public async Task Unknown_key_refreshes_once_and_accepts_rotated_key()
    {
        await _validator.ValidateAsync(Token());
        _handler.Jwks = Jwks("rotated");
        await _validator.ValidateAsync(Token(kid: "rotated"));
        Assert.Equal(2, _handler.Requests);
    }

    [Fact]
    public async Task Unknown_key_still_missing_after_refresh_is_rejected()
    {
        await _validator.ValidateAsync(Token());
        await Assert.ThrowsAnyAsync<SecurityTokenException>(() => _validator.ValidateAsync(Token(kid: "missing")));
        Assert.Equal(2, _handler.Requests);
    }

    [Fact]
    public async Task Wrong_signature_is_rejected()
    {
        using var otherRsa = RSA.Create(2048);
        await Assert.ThrowsAnyAsync<SecurityTokenException>(() => _validator.ValidateAsync(Token(rsa: otherRsa)));
    }

    [Fact]
    public async Task Non_rs256_algorithm_is_rejected_before_fetching_keys()
    {
        await Assert.ThrowsAsync<SecurityTokenException>(() => _validator.ValidateAsync(Token(algorithm: SecurityAlgorithms.RsaSha512)));
        Assert.Equal(0, _handler.Requests);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not-a-jwt")]
    public async Task Malformed_token_is_rejected(string token) =>
        await Assert.ThrowsAsync<SecurityTokenException>(() => _validator.ValidateAsync(token));

    private string Token(string issuer = "https://appleid.apple.com", string audience = "com.scooterapp.vgo",
        DateTime? expires = null, string? email = "USER@privaterelay.appleid.com", string kid = "original",
        RSA? rsa = null, string algorithm = SecurityAlgorithms.RsaSha256)
    {
        var claims = new List<Claim> { new("sub", "apple-user-id") };
        if (email != null) claims.Add(new Claim("email", email));
        var token = new JwtSecurityToken(issuer, audience, claims,
            notBefore: DateTime.UtcNow.AddHours(-1), expires: expires ?? DateTime.UtcNow.AddMinutes(5),
            signingCredentials: new SigningCredentials(new RsaSecurityKey(rsa ?? _rsa) { KeyId = kid }, algorithm));
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private string Jwks(string kid)
    {
        var parameters = _rsa.ExportParameters(false);
        return JsonSerializer.Serialize(new { keys = new[] { new
        {
            kty = "RSA", kid, use = "sig", alg = "RS256",
            n = Base64UrlEncoder.Encode(parameters.Modulus!),
            e = Base64UrlEncoder.Encode(parameters.Exponent!),
        } } });
    }

    public void Dispose()
    {
        _client.Dispose();
        _rsa.Dispose();
    }

    private sealed class FakeJwksHandler : HttpMessageHandler
    {
        public string Jwks { get; set; } = "";
        public int Requests { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Assert.Equal("https://appleid.apple.com/auth/keys", request.RequestUri!.AbsoluteUri);
            Requests++;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(Jwks) });
        }
    }
}
