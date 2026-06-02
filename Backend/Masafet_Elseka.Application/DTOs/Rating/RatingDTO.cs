using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.Rating
{
    public class RatingDTO
    {
        public int Score { get; set; }
        public string? Comment { get; set; }
        public string TripId { get; set; }
        public string FromUserId { get; set; }
        public string ToUserId { get; set; }
    }
}
