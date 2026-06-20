using System;

namespace Masafet_Elseka.Application.DTOs.Payment
{
    /// <summary>
    /// Safe view of a saved card for the client — never exposes the Paymob token.
    /// </summary>
    public class SavedCardDTO
    {
        public int Id { get; set; }
        public string MaskedPan { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
