using Masafet_Elseka.Application.Collection;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Services.CollectionService;
using Xunit;

namespace Masafet_Elseka.Tests
{
    // Templates follow the wallet notifications as captains and support forward them.
    // Add every new real message variant here (numbers / names masked) before changing
    // the parser.
    public class WalletSmsParserTests
    {
        [Fact]
        public void Vodafone_arabic_received()
        {
            var r = WalletSmsParser.Parse("VF-Cash",
                "تم استلام مبلغ 150.00 جنيه من رقم 01012345678؛ المسجل بإسم AHMED MOHAMED; رصيدك الحالي 1,250.50 جنيه. رقم العملية: 004512345678. التاريخ 06-10-26 21:14");
            Assert.Equal(WalletProvider.VodafoneCash, r.Provider);
            Assert.Equal(WalletSmsKind.Incoming, r.Kind);
            Assert.Equal(150.00m, r.Amount);
            Assert.Equal("01012345678", r.CounterpartyPhone);
            Assert.Equal("004512345678", r.TxnRef);
            Assert.Equal(1250.50m, r.BalanceAfter);
        }

        [Fact]
        public void Vodafone_english_received()
        {
            var r = WalletSmsParser.Parse("VF-Cash",
                "You have received 200.00 EGP from 01098765432 registered to MOHAMED ALI. Your current balance is 900.25 EGP. Transaction ID: 123456789012");
            Assert.Equal(WalletSmsKind.Incoming, r.Kind);
            Assert.Equal(200m, r.Amount);
            Assert.Equal("01098765432", r.CounterpartyPhone);
            Assert.Equal("123456789012", r.TxnRef);
            Assert.Equal(900.25m, r.BalanceAfter);
        }

        [Fact]
        public void Arabic_indic_digits()
        {
            var r = WalletSmsParser.Parse("VF-Cash",
                "تم استلام مبلغ ٣٢٠٫٥٠ جنيه من رقم ٠١١٢٣٤٥٦٧٨٩ رصيدك الحالي ٤٠٠ جنيه رقم العملية ٩٨٧٦٥٤٣٢١");
            Assert.Equal(WalletSmsKind.Incoming, r.Kind);
            Assert.Equal(320.50m, r.Amount);
            Assert.Equal("01123456789", r.CounterpartyPhone);
            Assert.Equal("987654321", r.TxnRef);
            Assert.Equal(400m, r.BalanceAfter);
        }

        [Fact]
        public void Etisalat_arabic_received()
        {
            var r = WalletSmsParser.Parse("Etisalat Cash",
                "تم استقبال مبلغ 75 جنيه من 01112345678 بنجاح. رقم العملية 556677889. رصيدك الحالي هو 175.00 جنيه");
            Assert.Equal(WalletProvider.EtisalatCash, r.Provider);
            Assert.Equal(WalletSmsKind.Incoming, r.Kind);
            Assert.Equal(75m, r.Amount);
            Assert.Equal("01112345678", r.CounterpartyPhone);
            Assert.Equal("556677889", r.TxnRef);
            Assert.Equal(175m, r.BalanceAfter);
        }

        [Fact]
        public void E_and_money_sender_is_etisalat()
        {
            Assert.Equal(WalletProvider.EtisalatCash, WalletSmsParser.ProviderFromSender("e& money"));
            Assert.Equal(WalletProvider.VodafoneCash, WalletSmsParser.ProviderFromSender("Vodafone"));
            Assert.Null(WalletSmsParser.ProviderFromSender("CIB"));
        }

        [Fact]
        public void International_prefix_is_normalised()
        {
            var r = WalletSmsParser.Parse("VF-Cash", "You have received EGP 50 from +201001234567. Balance: EGP 60");
            Assert.Equal(WalletSmsKind.Incoming, r.Kind);
            Assert.Equal(50m, r.Amount);
            Assert.Equal("01001234567", r.CounterpartyPhone);
            Assert.Equal(60m, r.BalanceAfter);
        }

        [Fact]
        public void Outgoing_transfer_is_not_incoming()
        {
            var r = WalletSmsParser.Parse("VF-Cash",
                "تم تحويل مبلغ 100 جنيه الى رقم 01012345678 بنجاح، مصاريف الخدمة 1 جنيه. رصيدك الحالي 49 جنيه. رقم العملية 11223344");
            Assert.Equal(WalletSmsKind.Outgoing, r.Kind);
            Assert.Equal(100m, r.Amount);
        }

        [Fact]
        public void Transfer_to_your_wallet_is_incoming()
        {
            var r = WalletSmsParser.Parse("VF-Cash",
                "تم تحويل مبلغ 60 جنيه الى محفظتك من رقم 01287654321. رقم العملية 44556677");
            Assert.Equal(WalletSmsKind.Incoming, r.Kind);
            Assert.Equal(60m, r.Amount);
            Assert.Equal("01287654321", r.CounterpartyPhone);
        }

        [Fact]
        public void Fee_is_not_the_amount()
        {
            var r = WalletSmsParser.Parse("VF-Cash",
                "رسوم الخدمة 2 جنيه. تم استلام مبلغ 500 جنيه من رقم 01511112222 رقم العملية 778899001");
            Assert.Equal(WalletSmsKind.Incoming, r.Kind);
            Assert.Equal(500m, r.Amount);
        }

        [Fact]
        public void Advertisement_is_ignored()
        {
            var r = WalletSmsParser.Parse("Vodafone",
                "استمتع بخصم 20% على مشترياتك مع فودافون كاش! ادفع بالكارت واكسب 50 جنيه كاش باك. للاشتراك اطلب *9#");
            Assert.NotEqual(WalletSmsKind.Incoming, r.Kind);
        }

        [Fact]
        public void Otp_is_ignored()
        {
            var r = WalletSmsParser.Parse("VF-Cash", "كود التفعيل الخاص بك هو 482913 لا تشاركه مع أحد");
            Assert.Equal(WalletSmsKind.Ignored, r.Kind);
            Assert.Null(r.Amount);
        }

        [Fact]
        public void Failed_transaction_is_ignored()
        {
            var r = WalletSmsParser.Parse("VF-Cash", "لم يتم استلام مبلغ 100 جنيه من رقم 01012345678 بسبب خطأ في العملية");
            Assert.Equal(WalletSmsKind.Ignored, r.Kind);
        }

        [Fact]
        public void Own_wallet_number_is_not_the_sender()
        {
            var r = WalletSmsParser.Parse("VF-Cash",
                "محفظتك 01000000001: تم استلام مبلغ 90 جنيه من 01033334444",
                new[] { "01000000001" });
            Assert.Equal("01033334444", r.CounterpartyPhone);
            Assert.Equal(90m, r.Amount);
        }

        [Fact]
        public void Thousands_separator()
        {
            var r = WalletSmsParser.Parse("VF-Cash", "تم استلام مبلغ 1,500.00 جنيه من رقم 01012345678");
            Assert.Equal(1500m, r.Amount);
        }

        [Fact]
        public void Received_without_amount_is_unparsed()
        {
            var r = WalletSmsParser.Parse("VF-Cash", "تم استلام تحويل من رقم 01012345678، برجاء مراجعة رصيدك");
            Assert.Equal(WalletSmsKind.Unparsed, r.Kind);
        }

        [Theory]
        [InlineData("01012345678", "01012345678")]
        [InlineData("+20 101 234 5678", "01012345678")]
        [InlineData("00201012345678", "01012345678")]
        [InlineData("٠١٠١٢٣٤٥٦٧٨", "01012345678")]
        [InlineData("0101234567", null)]
        [InlineData("01312345678", null)]
        public void Normalize_phone(string raw, string? expected) =>
            Assert.Equal(expected, WalletSmsParser.NormalizePhone(raw));
    }

    public class CollectionCycleTests
    {
        [Fact]
        public void Evening_notice_midnight_deadline()
        {
            // 21:30 -> round of today, deadline at the coming midnight.
            var (date, notice, deadline) = CollectionService.CurrentCycle(new DateTime(2026, 10, 7, 21, 30, 0), 20, 0);
            Assert.Equal(new DateTime(2026, 10, 7), date);
            Assert.Equal(new DateTime(2026, 10, 7, 20, 0, 0), notice);
            Assert.Equal(new DateTime(2026, 10, 8, 0, 0, 0), deadline);
        }

        [Fact]
        public void After_midnight_still_previous_round()
        {
            var (date, _, deadline) = CollectionService.CurrentCycle(new DateTime(2026, 10, 8, 0, 5, 0), 20, 0);
            Assert.Equal(new DateTime(2026, 10, 7), date);
            Assert.Equal(new DateTime(2026, 10, 8, 0, 0, 0), deadline);
        }

        [Fact]
        public void Afternoon_belongs_to_yesterdays_round()
        {
            var (date, notice, _) = CollectionService.CurrentCycle(new DateTime(2026, 10, 8, 15, 0, 0), 20, 0);
            Assert.Equal(new DateTime(2026, 10, 7), date);
            Assert.Equal(new DateTime(2026, 10, 7, 20, 0, 0), notice);
        }

        [Fact]
        public void Same_day_deadline()
        {
            var (_, _, deadline) = CollectionService.CurrentCycle(new DateTime(2026, 10, 8, 9, 0, 0), 8, 20);
            Assert.Equal(new DateTime(2026, 10, 8, 20, 0, 0), deadline);
        }
    }
}
