namespace Masafet_Elseka.Domain.Enums
{
    // Mobile wallets the company receives captain collections on.
    public enum WalletProvider
    {
        VodafoneCash = 1,
        EtisalatCash = 2,
        InstaPay = 3   // InstaPay address / account; receipts come as app notifications or bank SMS
    }

    // Where the collector phone read the receipt from.
    public enum WalletSmsSource
    {
        Sms = 1,
        Notification = 2
    }

    // What the parser made of a relayed SMS.
    public enum WalletSmsKind
    {
        Incoming = 1,  // money received on a company wallet (the only kind that can match)
        Outgoing = 2,  // transfer / payment made from the wallet
        Ignored = 3,   // ads, OTPs, balance notices
        Unparsed = 4   // looked like a transfer but amount / sender couldn't be read
    }

    // Where a relayed SMS stands in reconciliation.
    public enum WalletSmsMatchStatus
    {
        Unclaimed = 0,     // no captain request matches it (yet)
        Matched = 1,       // matched a captain request and credited automatically
        NeedsReview = 2,   // ambiguous or amount mismatch: an admin decides
        Assigned = 3,      // credited to a captain manually by an admin
        Dismissed = 4,     // not a captain collection (personal transfer, test...)
        NotApplicable = 5  // not an incoming transfer
    }

    // A captain's "I transferred X from number Y" claim.
    public enum CollectionRequestStatus
    {
        Pending = 0,     // waiting for the receipt SMS
        Confirmed = 1,   // matched with the receipt SMS, ledger credited
        NeedsReview = 2, // amount mismatch / ambiguous, an admin decides
        Rejected = 3,    // admin rejected it
        Expired = 4,     // no SMS arrived in time (a late SMS can still confirm it)
        Cancelled = 5    // the captain withdrew it
    }
}
