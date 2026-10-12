using Masafet_Elseka.Domain.Enums;

namespace Masafet_Elseka.Application.Collection
{
    // The anti-forgery balance chain (ported from VIP). Every wallet SMS that carries
    // "your balance is X" is checked against the balance the wallet should have:
    // a forged receipt can copy the wording, never the running balance.
    //
    // The expected balance is only an anchor: every message with a balance re-anchors
    // the chain after reporting whether the arithmetic held. Only a RECEIPT that doesn't
    // follow is a gap; an outgoing transfer (fees vary) or an unreadable money message
    // just resyncs, so the company's own payouts never pause collection.
    public static class BalanceChain
    {
        // Receipts in a row that don't follow the chain before the wallet pauses.
        public const int PauseAfterGaps = 3;

        public sealed record Step(WalletSmsChainStatus Status, decimal? Expected);

        public static Step Next(decimal? expected, WalletSmsKind kind, decimal? amount, decimal? balanceAfter)
        {
            switch (kind)
            {
                case WalletSmsKind.Incoming:
                    if (balanceAfter == null) return new(WalletSmsChainStatus.NoBalance, expected);
                    if (expected == null || amount == null) return new(WalletSmsChainStatus.First, balanceAfter);
                    return new(expected.Value + amount.Value == balanceAfter.Value ? WalletSmsChainStatus.Ok : WalletSmsChainStatus.Gap, balanceAfter);
                case WalletSmsKind.Outgoing:
                    // Money left but we can't tell where the balance stands: drop the anchor
                    // rather than call the next receipt forged.
                    if (balanceAfter == null) return new(WalletSmsChainStatus.NotApplicable, null);
                    if (expected == null || amount == null) return new(WalletSmsChainStatus.First, balanceAfter);
                    return new(expected.Value - amount.Value == balanceAfter.Value ? WalletSmsChainStatus.Ok : WalletSmsChainStatus.Resync, balanceAfter);
                case WalletSmsKind.Unparsed:
                    if (balanceAfter == null) return new(WalletSmsChainStatus.NotApplicable, expected);
                    return new(expected == null ? WalletSmsChainStatus.First : WalletSmsChainStatus.Resync, balanceAfter);
                default:
                    return new(WalletSmsChainStatus.NotApplicable, expected);
            }
        }

        // For a message that arrives AFTER a newer one is already on the chain (the
        // inbox sweep can deliver out of order): does it continue the balance of the
        // message just before it in time? It never moves the chain.
        public static WalletSmsChainStatus After(decimal? previousBalance, WalletSmsKind kind, decimal? amount, decimal? balanceAfter)
        {
            if (previousBalance == null || amount == null || balanceAfter == null) return WalletSmsChainStatus.NotApplicable;
            return kind switch
            {
                WalletSmsKind.Incoming => previousBalance.Value + amount.Value == balanceAfter.Value ? WalletSmsChainStatus.Ok : WalletSmsChainStatus.Stale,
                WalletSmsKind.Outgoing => previousBalance.Value - amount.Value == balanceAfter.Value ? WalletSmsChainStatus.Ok : WalletSmsChainStatus.Stale,
                _ => WalletSmsChainStatus.NotApplicable,
            };
        }

        public static int NextGapStreak(int streak, WalletSmsChainStatus status) => status switch
        {
            WalletSmsChainStatus.Gap => streak + 1,
            WalletSmsChainStatus.Ok => 0,
            _ => streak,
        };

        // Why a receipt can't be confirmed automatically, or null when it can.
        public static string? Blocks(WalletProvider? provider, WalletSmsChainStatus status, bool walletPaused)
        {
            // InstaPay has no balance on its notifications; the app push itself is the proof.
            if (provider == WalletProvider.InstaPay) return null;
            if (walletPaused) return "المحفظة متوقفة بسبب رصيد مش ماشي مع الرسايل — الإدارة هتراجع";
            return status switch
            {
                WalletSmsChainStatus.Ok => null,
                WalletSmsChainStatus.Gap => "الرصيد في الرسالة مش ماشي مع الرسالة اللي قبلها — اتأكد إن التحويل وصل فعلاً",
                WalletSmsChainStatus.First => "أول رسالة على المحفظة دي (مفيش رصيد قبلها نقارن بيه) — اتأكد إن التحويل وصل",
                WalletSmsChainStatus.NoBalance => "الرسالة مفيهاش الرصيد بعد التحويل، فمش هنقدر نتأكد إنها حقيقية",
                WalletSmsChainStatus.Stale => "الرسالة وصلت متأخرة ورصيدها مش ماشي مع اللي قبلها",
                _ => "الرصيد في الرسالة مش ممكن نراجعه",
            };
        }
    }
}
