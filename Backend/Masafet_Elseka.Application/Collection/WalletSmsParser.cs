using Masafet_Elseka.Domain.Enums;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Masafet_Elseka.Application.Collection
{
    public sealed record WalletSmsParseResult(
        WalletProvider? Provider,
        WalletSmsKind Kind,
        decimal? Amount,
        string? CounterpartyPhone,
        string? TxnRef,
        decimal? BalanceAfter,
        // InstaPay transfers name the sender by address (name@instapay) and/or name
        // instead of a phone number.
        string? CounterpartyAccount = null,
        string? CounterpartyName = null);

    // Reads Vodafone Cash / Etisalat (e&) Cash SMS and InstaPay notifications (the
    // InstaPay app, or a bank's SMS / push about an InstaPay transfer) in Arabic or English,
    // with Western or Arabic-Indic digits. Pure and stateless so it can be unit-tested
    // against real messages. Only "money received" messages can ever be matched to a
    // captain; everything else is classified so it shows up correctly for review.
    public static class WalletSmsParser
    {
        private const RegexOptions Opt = RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled;

        // Sender ids the collector phone forwards. Matched against the sender with spaces,
        // dashes and underscores removed, lower-cased.
        public static readonly string[] SenderHints = { "vfcash", "vodafone", "vf", "etisalat", "e&", "eand", "emoney", "etisalatcash", "instapay" };

        // Any SMS or app notification containing one of these is forwarded too: bank SMS
        // and bank-app pushes about InstaPay transfers come from many different senders.
        public static readonly string[] InstaPayKeywords = { "instapay", "insta pay", "انستاباي", "إنستاباي", "انستا باي", "إنستا باي" };

        // Apps whose notifications the collector phone forwards (besides keyword matches).
        public static readonly string[] NotificationPackages = { "com.egyptianbanks.instapay" };

        public static bool MentionsInstaPay(string? text) =>
            !string.IsNullOrEmpty(text) && InstaPayKeywords.Any(k => text.Contains(k, StringComparison.OrdinalIgnoreCase));

        public static WalletProvider? ProviderFromSender(string? sender)
        {
            if (string.IsNullOrWhiteSpace(sender)) return null;
            var s = Regex.Replace(sender, @"[\s\-_.]", "").ToLowerInvariant();
            if (s.Contains("vodafone") || s.StartsWith("vf")) return WalletProvider.VodafoneCash;
            if (s.Contains("etisalat") || s.Contains("e&") || s.StartsWith("eand") || s.Contains("emoney"))
                return WalletProvider.EtisalatCash;
            if (s.Contains("instapay")) return WalletProvider.InstaPay;
            return null;
        }

        // ---- normalisation ----

        public static string Normalize(string text)
        {
            var sb = new StringBuilder(text.Length);
            foreach (var ch in text)
            {
                switch (ch)
                {
                    case >= '٠' and <= '٩': sb.Append((char)('0' + ch - '٠')); break; // Arabic-Indic
                    case >= '۰' and <= '۹': sb.Append((char)('0' + ch - '۰')); break; // Persian
                    case '٫': sb.Append('.'); break;  // Arabic decimal separator
                    case '٬': sb.Append(','); break;  // Arabic thousands separator
                    case '،': sb.Append('،'); break;
                    case '‎' or '‏' or '​' or '‌' or '‍' or '﻿':
                    case >= '‪' and <= '‮':
                    case >= '⁦' and <= '⁩':
                        break; // direction / zero-width marks
                    case ' ' or '\r' or '\n' or '\t': sb.Append(' '); break;
                    default: sb.Append(ch); break;
                }
            }
            // Unify alef / teh-marbuta variants so keyword checks don't depend on spelling.
            var s = sb.ToString().Replace('إ', 'ا').Replace('أ', 'ا').Replace('آ', 'ا');
            return Regex.Replace(s, @" {2,}", " ").Trim();
        }

        // ---- classification ----

        private static readonly Regex Failed = new(@"لم يتم|فشل|مرفوض|رفض|failed|declined|unsuccessful|not completed|insufficient", Opt);
        private static readonly Regex Incoming = new(
            @"استلام|استقبال|استلمت|وصل(?:ك|تك|ت لك)|تم اضافة|اضيف|ايداع|حول لك|حوّل لك|(?:الى|ل)\s*محفظتك|received|credited|deposited|added to your|transferred to you|to your wallet|you got", Opt);
        private static readonly Regex Outgoing = new(
            @"تم تحويل|حولت|تم دفع|تم الدفع|دفعت|تم سحب|سحب نقدي|تم شراء|تم شحن|you have sent|you sent|sent to|transferred to|paid|payment of|withdraw|debited|purchase", Opt);

        // ---- money ----

        private const string Num = @"(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)";
        private const string Currency = @"(?:جنيه(?:ا|ات)?|جنية|جم|ج\.\s?م\.?|ج\s?م|ج\.|EGP|LE|L\.E\.?)";
        private static readonly Regex MoneyAfter = new(@"(?<![\d.,])" + Num + @"\s*" + Currency + @"(?![A-Za-z])", Opt);
        private static readonly Regex MoneyBefore = new(@"(?<![A-Za-z])(?:EGP|LE|L\.E\.?)\s*" + Num + @"(?![\d])", Opt);
        private static readonly Regex MoneyMablagh = new(@"مبلغ\s*(?:و?قدره\s*)?" + Num + @"(?![\d])", Opt);
        private static readonly Regex BalanceCue = new(@"رصيد|balance", Opt);
        private static readonly Regex FeeCue = new(@"رسوم|مصاريف|مصروفات|عمولة|fees?|charges?|commission", Opt);

        // ---- phone / reference ----

        private static readonly Regex InstaPayAddress = new(@"([A-Za-z0-9][A-Za-z0-9._\-]{1,60}@instapay)\b", Opt);
        // Sender name after "from / من" up to the next field (address, date, reference...).
        private static readonly Regex NameAfterFrom = new(
            @"(?:^|[\s:،,(])(?:from|من|بواسطة|المرسل|sender)\s*[:：]?\s*(?<name>[\p{L}*][\p{L}\s.'*\-]{1,60}?)\s*(?=$|[(\[،,.;:|\d]|\s(?:on|at|via|ref|بتاريخ|يوم|في|عبر|على|رقم|الساعة|to|الى|إلى)(?:\s|$))",
            Opt);
        private static readonly string[] NotNames = { "رقم", "الرقم", "محفظة", "حساب", "number", "account", "wallet", "mobile", "instapay", "انستاباي" };

        private static readonly Regex Phone = new(@"(?<!\d)(?:\+?2|002)?(01[0125]\d{8})(?!\d)", Opt);
        private static readonly Regex FromCue = new(@"(?:^|[\s:،,(])(?:من|from|by|بواسطة)(?:\s+(?:رقم|الرقم|محفظة|number|wallet|mobile))?\s*[:：]?\s*$", Opt);
        private static readonly Regex Reference = new(
            @"(?:رقم\s*(?:ال)?(?:عملي[ةه]|معامل[ةه]|مرجع|تحويل|حركة)|كود\s*(?:ال)?عملي[ةه]|مرجع(?:ي)?|transaction\s*(?:id|no\.?|number|ref(?:erence)?)?|trx\s*(?:id|no\.?)?|txn\s*(?:id|no\.?)?|ref(?:erence)?\s*(?:no\.?|number|id)?|operation\s*(?:id|no\.?|number))\s*[:：#.]?\s*([A-Za-z0-9\-]{5,40})",
            Opt);

        private sealed record Money(int Index, int End, decimal Value);

        private static decimal? ParseNumber(string raw) =>
            decimal.TryParse(raw.Replace(",", ""), NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var v) ? v : null;

        private static List<Money> FindMoney(string text)
        {
            var found = new List<Money>();
            void Add(Regex rx)
            {
                foreach (Match m in rx.Matches(text))
                {
                    var g = m.Groups[1];
                    if (found.Any(f => Math.Abs(f.Index - g.Index) < 3)) continue;
                    // A phone number is never money.
                    if (g.Value.Length >= 10 && !g.Value.Contains('.') && !g.Value.Contains(',')) continue;
                    var v = ParseNumber(g.Value);
                    if (v is > 0 and < 1_000_000) found.Add(new Money(g.Index, m.Index + m.Length, v.Value));
                }
            }
            Add(MoneyAfter);
            Add(MoneyBefore);
            Add(MoneyMablagh);
            return found.OrderBy(f => f.Index).ToList();
        }

        private static string Before(string text, int index, int chars) =>
            text.Substring(Math.Max(0, index - chars), Math.Min(chars, index));

        public static WalletSmsParseResult Parse(string? sender, string? body, IEnumerable<string>? ownNumbers = null)
        {
            var provider = ProviderFromSender(sender);
            if (string.IsNullOrWhiteSpace(body))
                return new(provider, WalletSmsKind.Ignored, null, null, null, null);

            var text = Normalize(body);
            var own = new HashSet<string>(ownNumbers ?? Enumerable.Empty<string>());

            // Amount = the first sum that isn't introduced as a balance or a fee.
            decimal? amount = null, balance = null;
            var previousEnd = 0;
            foreach (var m in FindMoney(text))
            {
                // Look only at the words right before the number: after the previous sum
                // and the last sentence break, at most 28 characters back.
                var start = Math.Max(previousEnd, m.Index - 28);
                var lead = start < m.Index ? text[start..m.Index] : string.Empty;
                previousEnd = Math.Max(previousEnd, m.End);
                var cut = lead.LastIndexOfAny(new[] { '.', '؛', ';', '!' });
                var near = cut >= 0 && cut < lead.Length - 1 ? lead[(cut + 1)..] : lead;
                if (BalanceCue.IsMatch(near)) { balance ??= m.Value; continue; }
                if (FeeCue.IsMatch(near)) continue;
                amount ??= m.Value;
            }

            // Counterparty = the number introduced by "from / من", else the first number
            // that isn't one of our own wallets.
            string? phone = null, fallback = null;
            foreach (Match m in Phone.Matches(text))
            {
                var number = m.Groups[1].Value;
                if (own.Contains(number)) continue;
                fallback ??= number;
                if (FromCue.IsMatch(Before(text, m.Index, 22))) { phone = number; break; }
            }
            phone ??= fallback;

            string? reference = null;
            foreach (Match m in Reference.Matches(text))
            {
                var token = m.Groups[1].Value.Trim('-');
                // A real reference carries digits; skip words caught by a loose label.
                if (token.Count(char.IsDigit) >= 5 && token != phone) { reference = token; break; }
            }

            var account = InstaPayAddress.Matches(text)
                .Select(m => m.Groups[1].Value.ToLowerInvariant())
                .FirstOrDefault(x => !own.Contains(x));
            string? name = null;
            foreach (Match m in NameAfterFrom.Matches(text))
            {
                var candidate = Regex.Replace(m.Groups["name"].Value, @"\s{2,}", " ").Trim(' ', '.', '-', '*');
                if (candidate.Length < 3 || NotNames.Any(n => candidate.StartsWith(n, StringComparison.OrdinalIgnoreCase))) continue;
                name = candidate;
                break;
            }
            // The InstaPay app itself, or a bank SMS / push about an InstaPay transfer.
            if (provider == null && (account != null || MentionsInstaPay(text))) provider = WalletProvider.InstaPay;

            WalletSmsKind kind;
            if (Failed.IsMatch(text))
                kind = WalletSmsKind.Ignored;
            else if (Incoming.IsMatch(text) && !OutgoingDominates(text))
                kind = amount != null ? WalletSmsKind.Incoming
                    : (phone != null || account != null || name != null) ? WalletSmsKind.Unparsed : WalletSmsKind.Ignored;
            else if (Outgoing.IsMatch(text))
                kind = WalletSmsKind.Outgoing;
            else
                kind = amount != null && phone != null ? WalletSmsKind.Unparsed : WalletSmsKind.Ignored;

            return new(provider, kind, amount, phone, reference, balance, account, name);
        }

        // "تم تحويل مبلغ ... الى رقم ..." also contains "استلام" in some templates
        // ("سيتم استلامه"); a transfer *to* someone else wins when it comes first.
        private static bool OutgoingDominates(string text)
        {
            var o = Outgoing.Match(text);
            var i = Incoming.Match(text);
            if (!o.Success) return false;
            if (Regex.IsMatch(text, @"(?:الى|إلى|لـ?)\s*(?:محفظتك|حسابك)|to your (?:wallet|account)", Opt)) return false;
            return o.Index < i.Index;
        }

        // InstaPay address in canonical lower-case form (name@instapay), or null.
        public static string? NormalizeInstaPayAddress(string? raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return null;
            var s = raw.Trim().ToLowerInvariant().Replace(" ", "");
            return Regex.IsMatch(s, @"^[a-z0-9][a-z0-9._\-]{1,60}@instapay$") ? s : null;
        }

        private static List<string> NameTokens(string name)
        {
            // Normalize() already unifies the alef forms.
            var s = Normalize(name).ToLowerInvariant().Replace('ة', 'ه').Replace('ى', 'ي');
            // "عبد الله" / "abdel rahman" are one name however they're spaced.
            s = Regex.Replace(s, @"(^|\s)(عبد|abd|abdel|abdul|abd el)\s+", "$1$2");
            return Regex.Split(s, @"[^\p{L}]+").Where(t => t.Length >= 2).ToList();
        }

        // Does a name on a receipt (often shortened or masked: "MOHAMED A***") belong to
        // the name the captain typed? null when they can't be compared (Arabic vs Latin).
        public static bool? NamesMatch(string? a, string? b)
        {
            if (string.IsNullOrWhiteSpace(a) || string.IsNullOrWhiteSpace(b)) return null;
            var x = NameTokens(a);
            var y = NameTokens(b);
            if (x.Count == 0 || y.Count == 0) return null;
            static bool Latin(List<string> t) => t.All(w => w.All(c => c < 128));
            if (Latin(x) != Latin(y)) return null;

            var shared = x.Intersect(y).Count();
            if (shared >= 2) return true;
            // One side is just a first name (or the rest is masked): the first names agree.
            if ((x.Count == 1 || y.Count == 1) && x[0] == y[0]) return true;
            return false;
        }

        // Egyptian mobile in the canonical 01XXXXXXXXX form, or null.
        public static string? NormalizePhone(string? raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return null;
            var m = Phone.Match(Normalize(raw).Replace(" ", "").Replace("-", ""));
            return m.Success ? m.Groups[1].Value : null;
        }
    }
}
