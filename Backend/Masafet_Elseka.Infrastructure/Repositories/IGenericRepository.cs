using Microsoft.EntityFrameworkCore.Storage;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Repositories
{
    public interface IGenericRepository<T> where T : class
    {
        IDbContextTransaction BeginTransaction();
        Task<T> GetByIdAsync(string id);
        Task<T> GetByIdAsync(int id);
        Task<T> GetByIdWithIncludeAsync(string id, params Expression<Func<T, object>>[] includeProperties);
        Task<T> GetByExpressionAsync(Expression<Func<T, bool>> predicate);
        Task<T> GetByExpressionAsync(Expression<Func<T, bool>> predicate, CancellationToken ct);
        IQueryable<T> GetQueryable(
           Expression<Func<T, bool>>? filter = null,
           string? includeProperties = null,
           Func<IQueryable<T>, IOrderedQueryable<T>>? orderBy = null);
        Task<IEnumerable<T>> GetAllByExpressionAsync(Expression<Func<T, bool>> predicate, CancellationToken ct = default);

        public Task<IEnumerable<T>> GetAllByExpressionAsync(
           Expression<Func<T, bool>> predicate,
           Func<IQueryable<T>, IQueryable<T>> include = null , CancellationToken ct=default);
        public Task<T?> GetFirstOrDefaultAsync();

        Task<IEnumerable<T>> GetAllAsync();
        Task<T> AddAsync(T entity,CancellationToken ct=default);
        Task AddRangeAsync(IEnumerable<T> entities);
        Task UpdateAsync(T entity);
        Task UpdateRangeAsync(ICollection<T> entities);
        Task DeleteAsync(T entity);
        Task DeleteRangeAsync(IEnumerable<T> entities);
        Task<int> CountAsync(Expression<Func<T, bool>>? expression = default);
        Task<bool> AnyAsync(Expression<Func<T, bool>> predicate);

        Task SaveChangesAsync();
        void Commit();
        void RollBack();
    }
}
