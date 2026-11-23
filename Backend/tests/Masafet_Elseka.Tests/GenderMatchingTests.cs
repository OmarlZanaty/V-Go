using Masafet_Elseka.Application.DTOs;
using Masafet_Elseka.Application.DTOs.Driver;
using Masafet_Elseka.Application.ExternalInterfaces.ICachService;
using Masafet_Elseka.Application.Helpers;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Services.DriverFinanceService;
using Masafet_Elseka.Infrastructure.Services.DriverService;
using Xunit;

namespace Masafet_Elseka.Tests
{
    public class GenderMatchingTests
    {
        private sealed class FakeCache : ICacheService
        {
            public Dictionary<string, object> Data { get; } = new();
            public T? GetData<T>(string key) => Data.TryGetValue(key, out var v) ? (T)v : default;
            public void SetData<T>(string key, T value, TimeSpan? expiration = null) => Data[key] = value!;
            public Task SetKeyToList(string keysList, string key) => Task.CompletedTask;
            public Task RemoveDataAsync(string key) { Data.Remove(key); return Task.CompletedTask; }
            public Task RemoveKeyFromList(string keysList, string key) => Task.CompletedTask;
        }

        [Theory]
        [InlineData("Male", "Male")]
        [InlineData("male", "Male")]
        [InlineData("  MALE ", "Male")]
        [InlineData("ذكر", "Male")]
        [InlineData("Female", "Female")]
        [InlineData("female", "Female")]
        [InlineData("أنثى", "Female")]
        [InlineData("انثى", "Female")]
        [InlineData(null, null)]
        [InlineData("", null)]
        [InlineData("unspecified", null)]
        public void Normalize_maps_every_spelling_to_Male_or_Female(string? input, string? expected)
            => Assert.Equal(expected, GenderHelper.Normalize(input));

        [Theory]
        [InlineData("Male", "Male", true)]
        [InlineData("female", "Female", true)]
        [InlineData("Female", "Male", false)]
        [InlineData("Male", "Female", false)]
        [InlineData("Female", "ذكر", false)]
        [InlineData(null, "Male", true)]      // legacy/unknown counts as Male
        [InlineData(null, "Female", false)]
        [InlineData("Female", null, false)]
        public void IsCompatible_never_crosses_genders(string? client, string? driver, bool expected)
            => Assert.Equal(expected, GenderHelper.IsCompatible(client, driver));

        private static DriverService NewService(out FakeCache cache, out Masafet_Elseka.Infrastructure.Data.Context db)
        {
            db = BetaServiceTests.NewDb();
            cache = new FakeCache();
            return new DriverService(null!, null!, cache, db, null!, null!);
        }

        [Fact]
        public async Task Filter_keeps_only_same_gender_and_resolves_missing_gender_from_db()
        {
            var svc = NewService(out var cache, out var db);
            db.Users.AddRange(
                new ApplicationUser { Id = "f1", FullName = "F1", Gender = "Female" },
                new ApplicationUser { Id = "m1", FullName = "M1", Gender = "Male" },
                new ApplicationUser { Id = "m2", FullName = "M2", Gender = "male" });
            await db.SaveChangesAsync();
            var drivers = new List<DriverStatusDTO>
            {
                new() { DriverId = "f1", IsAvailable = true, DriverGender = null },     // missing in cache -> DB says Female
                new() { DriverId = "m1", IsAvailable = true, DriverGender = "Male" },
                new() { DriverId = "m2", IsAvailable = true, DriverGender = "" },       // missing -> DB says male
                new() { DriverId = "ghost", IsAvailable = true, DriverGender = null },  // unknown user -> legacy Male
            };

            var forFemale = await svc.FilterByGenderAsync(drivers.Select(Clone).ToList(), "Female");
            Assert.Equal(new[] { "f1" }, forFemale.Select(d => d.DriverId));

            var forMale = await svc.FilterByGenderAsync(drivers.Select(Clone).ToList(), "male");
            Assert.Equal(new[] { "ghost", "m1", "m2" }, forMale.Select(d => d.DriverId).OrderBy(x => x));
            // resolved gender is written back so the next call needs no DB hit
            Assert.Equal("Female", cache.GetData<DriverStatusDTO>("DriverStatus_f1")!.DriverGender);
        }

        [Fact]
        public async Task GetDriverGender_reads_db_and_defaults_to_Male()
        {
            var svc = NewService(out _, out var db);
            db.Users.Add(new ApplicationUser { Id = "f", FullName = "F", Gender = "أنثى" });
            await db.SaveChangesAsync();
            Assert.Equal("Female", await svc.GetDriverGenderAsync("f"));
            Assert.Equal("Male", await svc.GetDriverGenderAsync("nobody"));
        }

        private static DriverStatusDTO Clone(DriverStatusDTO d) => new()
        {
            DriverId = d.DriverId, IsAvailable = d.IsAvailable, DriverGender = d.DriverGender
        };

        [Theory]
        [InlineData(null, false)]
        [InlineData("", false)]
        [InlineData("other", false)]
        [InlineData("Male", true)]
        [InlineData("female", true)]
        [InlineData("أنثى", true)]
        public void RegisterValidator_requires_a_valid_gender(string? gender, bool valid)
        {
            var dto = new RegisterDTO
            {
                FullName = "Test User", Email = "t@example.com", Phone = "01012345678", Gender = gender,
                Role = "Client", Password = "123456", ConfirmPassword = "123456",
            };
            var result = new RegisterValidator().Validate(dto);
            Assert.Equal(valid, !result.Errors.Any(e => e.PropertyName == nameof(RegisterDTO.Gender)));
        }

        [Fact]
        public void Criminal_record_is_required_for_new_captains_but_not_for_approved_ones()
        {
            Assert.Contains(DriverDocumentType.CriminalRecord, DriverFinanceService.RequiredDocuments);
            Assert.DoesNotContain(DriverDocumentType.CriminalRecord, DriverFinanceService.LegacyRequiredDocuments);
            Assert.Equal(DriverFinanceService.LegacyRequiredDocuments.Length + 1, DriverFinanceService.RequiredDocuments.Length);

            foreach (var s in new[] { DriverVerificationStatus.PendingDocuments, DriverVerificationStatus.UnderReview,
                                      DriverVerificationStatus.Rejected, DriverVerificationStatus.Suspended })
                Assert.Contains(DriverDocumentType.CriminalRecord, DriverFinanceService.RequiredFor(s));

            // grandfathered: an already-approved captain is never asked for it
            Assert.DoesNotContain(DriverDocumentType.CriminalRecord, DriverFinanceService.RequiredFor(DriverVerificationStatus.Approved));
        }
    }
}
