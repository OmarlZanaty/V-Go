using Masafet_Elseka.Application.DTOs;
using Masafet_Elseka.Application.Helpers;
using Xunit;

namespace Masafet_Elseka.Tests
{
    public class GenderSignupTests
    {
        [Fact]
        public void Rider_without_gender_is_created_Male_unconfirmed()
        {
            foreach (var v in new string?[] { null, "", "  " })
            {
                var r = GenderHelper.ResolveForSignup(v, isRider: true);
                Assert.False(r.Error);
                Assert.Equal("Male", r.Gender);
                Assert.False(r.Confirmed);
            }
        }

        [Fact]
        public void Rider_with_Female_is_confirmed()
        {
            var r = GenderHelper.ResolveForSignup("female", true);
            Assert.False(r.Error);
            Assert.Equal("Female", r.Gender);
            Assert.True(r.Confirmed);
        }

        [Fact]
        public void Rider_with_invalid_gender_is_rejected()
            => Assert.True(GenderHelper.ResolveForSignup("unspecified", true).Error);

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("bogus")]
        public void Captain_without_or_invalid_gender_is_rejected(string? g)
            => Assert.True(GenderHelper.ResolveForSignup(g, isRider: false).Error);

        [Fact]
        public void Captain_with_gender_is_confirmed()
        {
            var r = GenderHelper.ResolveForSignup("Male", false);
            Assert.False(r.Error);
            Assert.True(r.Confirmed);
        }

        private static RegisterDTO Dto(string role, string? gender) => new RegisterDTO
        {
            FullName = "Test User",
            Email = "a@b.com",
            Phone = "01012345678",
            Gender = gender!,
            Role = role,
            Password = "123456",
            ConfirmPassword = "123456",
        };

        [Fact]
        public void Validator_allows_Client_without_gender()
            => Assert.True(new RegisterValidator().Validate(Dto("Client", null)).IsValid);

        [Fact]
        public void Validator_accepts_Client_with_Female()
            => Assert.True(new RegisterValidator().Validate(Dto("Client", "Female")).IsValid);

        [Fact]
        public void Validator_rejects_Client_with_invalid_gender()
            => Assert.False(new RegisterValidator().Validate(Dto("Client", "xyz")).IsValid);

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        public void Validator_rejects_Driver_without_gender(string? g)
            => Assert.False(new RegisterValidator().Validate(Dto("Driver", g)).IsValid);
    }
}
