using Masafet_Elseka.Application.Collection;
using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Domain.Enums;
using Masafet_Elseka.Infrastructure.Services.CollectionService;
using Xunit;

namespace Masafet_Elseka.Tests
{
    public class BalanceChainTests
    {
        [Fact]
        public void Receipt_that_follows_the_balance_is_ok()
        {
            var step = BalanceChain.Next(100m, WalletSmsKind.Incoming, 50m, 150m);
            Assert.Equal(WalletSmsChainStatus.Ok, step.Status);
            Assert.Equal(150m, step.Expected);
        }

        [Fact]
        public void Receipt_that_does_not_follow_is_a_gap_and_reanchors()
        {
            var step = BalanceChain.Next(100m, WalletSmsKind.Incoming, 50m, 900m);
            Assert.Equal(WalletSmsChainStatus.Gap, step.Status);
            Assert.Equal(900m, step.Expected);
        }

        [Fact]
        public void First_message_anchors()
        {
            var step = BalanceChain.Next(null, WalletSmsKind.Incoming, 50m, 150m);
            Assert.Equal(WalletSmsChainStatus.First, step.Status);
            Assert.Equal(150m, step.Expected);
        }

        [Fact]
        public void Outgoing_with_fee_resyncs_instead_of_gap()
        {
            // 11 sent + 1 fee: the balance drops by 12, not 11.
            var step = BalanceChain.Next(36.10m, WalletSmsKind.Outgoing, 11m, 24.10m);
            Assert.Equal(WalletSmsChainStatus.Resync, step.Status);
            Assert.Equal(24.10m, step.Expected);
            Assert.Equal(0, BalanceChain.NextGapStreak(0, step.Status));
        }

        [Fact]
        public void Outgoing_without_balance_drops_the_anchor()
        {
            var step = BalanceChain.Next(100m, WalletSmsKind.Outgoing, 20m, null);
            Assert.Null(step.Expected);
        }

        [Fact]
        public void Receipt_without_balance_keeps_the_anchor()
        {
            var step = BalanceChain.Next(100m, WalletSmsKind.Incoming, 20m, null);
            Assert.Equal(WalletSmsChainStatus.NoBalance, step.Status);
            Assert.Equal(100m, step.Expected);
        }

        [Fact]
        public void Three_gaps_in_a_row_reach_the_pause()
        {
            var streak = 0;
            streak = BalanceChain.NextGapStreak(streak, WalletSmsChainStatus.Gap);
            streak = BalanceChain.NextGapStreak(streak, WalletSmsChainStatus.Resync);
            streak = BalanceChain.NextGapStreak(streak, WalletSmsChainStatus.Gap);
            streak = BalanceChain.NextGapStreak(streak, WalletSmsChainStatus.Gap);
            Assert.Equal(BalanceChain.PauseAfterGaps, streak);
            Assert.Equal(0, BalanceChain.NextGapStreak(streak, WalletSmsChainStatus.Ok));
        }

        [Fact]
        public void Late_message_is_checked_against_the_one_before_it()
        {
            Assert.Equal(WalletSmsChainStatus.Ok, BalanceChain.After(100m, WalletSmsKind.Incoming, 50m, 150m));
            Assert.Equal(WalletSmsChainStatus.Stale, BalanceChain.After(100m, WalletSmsKind.Incoming, 50m, 170m));
            Assert.Equal(WalletSmsChainStatus.NotApplicable, BalanceChain.After(null, WalletSmsKind.Incoming, 50m, 150m));
        }

        [Fact]
        public void Only_an_ok_chain_confirms_a_wallet_receipt()
        {
            Assert.Null(BalanceChain.Blocks(WalletProvider.VodafoneCash, WalletSmsChainStatus.Ok, false));
            Assert.NotNull(BalanceChain.Blocks(WalletProvider.VodafoneCash, WalletSmsChainStatus.Gap, false));
            Assert.NotNull(BalanceChain.Blocks(WalletProvider.EtisalatCash, WalletSmsChainStatus.First, false));
            Assert.NotNull(BalanceChain.Blocks(WalletProvider.EtisalatCash, WalletSmsChainStatus.Ok, true));
            // InstaPay notifications carry no balance; the app push is the proof.
            Assert.Null(BalanceChain.Blocks(WalletProvider.InstaPay, WalletSmsChainStatus.NotApplicable, false));
        }

        [Fact]
        public void Real_receipts_follow_each_other()
        {
            // Two real e& receipts in a row (numbers masked): 6236.91 + 11 = 6247.91.
            var first = WalletSmsParser.Parse("et money",
                "تم إستلام مبلغ 5.00 ج.م من رقم 01022223333 المسجل باسمAhmed M Hassan  بنجاح. رصيد محفظتك الحالى 6236.91 ج.م.");
            var second = WalletSmsParser.Parse("et money",
                "You have received 11.00 EGP from number 01000000001 registered to Ahmed S Ali successfully. Your current wallet balance is 6247.91 EGP.");
            var a = BalanceChain.Next(null, first.Kind, first.Amount, first.BalanceAfter);
            var b = BalanceChain.Next(a.Expected, second.Kind, second.Amount, second.BalanceAfter);
            Assert.Equal(WalletSmsChainStatus.Ok, b.Status);
        }
    }

    public class ChooseWalletTests
    {
        private static readonly Guid Phone = Guid.NewGuid();

        private static CollectionWallet W(int id, WalletProvider p, int? slot, Guid? device = null) =>
            new() { Id = id, Provider = p, SimSlot = slot, DeviceId = device ?? Phone };

        [Fact]
        public void One_wallet_of_the_kind_takes_the_message()
        {
            var wallets = new[] { W(1, WalletProvider.VodafoneCash, null), W(2, WalletProvider.EtisalatCash, null) };
            Assert.Equal(1, CollectionService.ChooseWallet(wallets, Phone, WalletProvider.VodafoneCash, null));
            Assert.Equal(2, CollectionService.ChooseWallet(wallets, Phone, WalletProvider.EtisalatCash, 2));
        }

        [Fact]
        public void Two_wallets_of_one_kind_are_told_apart_by_sim()
        {
            var wallets = new[] { W(1, WalletProvider.VodafoneCash, 1), W(2, WalletProvider.VodafoneCash, 2) };
            Assert.Equal(1, CollectionService.ChooseWallet(wallets, Phone, WalletProvider.VodafoneCash, 1));
            Assert.Equal(2, CollectionService.ChooseWallet(wallets, Phone, WalletProvider.VodafoneCash, 2));
            // Without the SIM the phone can't say which: unlinked.
            Assert.Null(CollectionService.ChooseWallet(wallets, Phone, WalletProvider.VodafoneCash, null));
        }

        [Fact]
        public void Wallet_pinned_to_the_other_sim_does_not_take_it()
        {
            var wallets = new[] { W(1, WalletProvider.VodafoneCash, 1) };
            Assert.Null(CollectionService.ChooseWallet(wallets, Phone, WalletProvider.VodafoneCash, 2));
        }

        [Fact]
        public void Other_phones_wallets_are_ignored()
        {
            var wallets = new[] { W(1, WalletProvider.VodafoneCash, null, Guid.NewGuid()) };
            Assert.Null(CollectionService.ChooseWallet(wallets, Phone, WalletProvider.VodafoneCash, null));
        }
    }
}
