namespace Masafet_Elseka.Application.DTOs.Payment
{
    // The client relays Paymob's redirect (response) callback here after the checkout
    // webview closes. Query is the raw query string (the part after '?') of that
    // redirect URL; it carries the transaction fields plus the HMAC we validate.
    public class PaymentCallbackDTO
    {
        public string Query { get; set; } = string.Empty;
    }
}
