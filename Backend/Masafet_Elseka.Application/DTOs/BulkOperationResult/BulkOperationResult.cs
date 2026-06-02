using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Application.DTOs.BulkOperationResult
{
    public class BulkOperationResult
    {
        public List<string> SucceededIds { get; set; } = new();
        public List<string> NotFoundIds { get; set; } = new();
        public List<FailedItem> Failed { get; set; } = new();

        public int SuccessCount => SucceededIds.Count;
        public int FailedCount => Failed.Count;
        public int NotFoundCount => NotFoundIds.Count;
    }

    public class FailedItem
    {
        public string Id { get; set; } = string.Empty;
        public string Reason { get; set; } = string.Empty;
    }

}
