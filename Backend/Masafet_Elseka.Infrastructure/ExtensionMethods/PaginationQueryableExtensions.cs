using Masafet_Elseka.Application.Common.Pagination;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExtensionMethods
{
    public static class PaginationQueryableExtensions
    {
        public static async Task<PaginationPagedResponse<T>> ToPagedResponseAsync<T>(
            this IQueryable<T> query,
            int pageNumber,
            int pageSize,
            CancellationToken ct = default)
        {
            var totalCount = await query.CountAsync(ct);
            var data = await query
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(ct);

            return new PaginationPagedResponse<T>(data, totalCount, pageNumber, pageSize);
        }
    }

}
