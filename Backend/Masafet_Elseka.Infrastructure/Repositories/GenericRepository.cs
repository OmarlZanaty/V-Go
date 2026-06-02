using Masafet_Elseka.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Repositories
{
    public class GenericRepository<T>: IGenericRepository<T> where T : class
    {
        protected readonly Context _dbContext;
        private readonly DbSet<T> _dbSet;
        public GenericRepository(Context context)
        {
            _dbContext = context;
            _dbSet = context.Set<T>();
        }


        public virtual async Task<T> AddAsync(T entity,CancellationToken ct = default)
        {
            await _dbSet.AddAsync(entity, ct);
            await _dbContext.SaveChangesAsync(ct);
            return entity;
        }


        public virtual async Task AddRangeAsync(IEnumerable<T> entities)
        {
            await _dbSet.AddRangeAsync(entities);
            await _dbContext.SaveChangesAsync();
        }

        public async Task<int> CountAsync(Expression<Func<T, bool>>? expression = default)
        {
            if (expression is null)
            {
                return await _dbSet.CountAsync();
            }
            return await _dbSet.CountAsync(expression);
        }
        public virtual async Task DeleteAsync(T entity)
        {
            _dbSet.Remove(entity);
        }
        public virtual async Task DeleteRangeAsync(IEnumerable<T> entities)
        {
            _dbSet.RemoveRange(entities);
        }


        public virtual async Task<IEnumerable<T>> GetAllAsync()
        {
            return await _dbSet.ToListAsync();

        }
        public virtual async Task<T?> GetFirstOrDefaultAsync()
        {
            return await _dbSet.FirstOrDefaultAsync();
        }

        public virtual async Task<T> GetByIdAsync(int id)
        {
            return await _dbSet.FindAsync(id);
        }
        public virtual async Task<T> GetByIdAsync(string id)
        {
            return await _dbSet.FindAsync(id);
        }
 

        public virtual async Task<T> GetByIdWithIncludeAsync(string id, params Expression<Func<T, object>>[] includeProperties)
        {
            IQueryable<T> query = _dbSet;

            foreach (var includeProperty in includeProperties)
            {
                query = query.Include(includeProperty);
            }

            return await query.FirstOrDefaultAsync(entity => EF.Property<string>(entity, "Id") == id);
        }

        public virtual async Task<T> GetByExpressionAsync(Expression<Func<T, bool>> predicate) // this to compare more than one condition
        {
            return await _dbSet.FirstOrDefaultAsync(predicate);
        }
        public virtual async Task<T> GetByExpressionAsync(Expression<Func<T, bool>> predicate, CancellationToken ct) // this to compare more than one condition , with Canceltion token
        {
            return await _dbSet.FirstOrDefaultAsync(predicate);
        }

        public virtual async Task<IEnumerable<T>> GetAllByExpressionAsync(Expression<Func<T, bool>> predicate,CancellationToken ct=default)
        {


            var results = await _dbSet.Where(predicate).ToListAsync();
            return results ?? Enumerable.Empty<T>();

        }

        public async Task<IEnumerable<T>> GetAllByExpressionAsync(
    Expression<Func<T, bool>> predicate,
    Func<IQueryable<T>, IQueryable<T>> include = null,CancellationToken ct=default)
        {
            IQueryable<T> query = _dbSet.Where(predicate);

            if (include != null)
            {
                query = include(query);
            }

            return await query.ToListAsync();
        }



        public async Task SaveChangesAsync()
        {
            await _dbContext.SaveChangesAsync();
        }

        public virtual async System.Threading.Tasks.Task UpdateAsync(T entity)
        {
            _dbSet.Update(entity);
        }

        public virtual async Task UpdateRangeAsync(ICollection<T> entities)
        {
            _dbSet.UpdateRange(entities);
            await _dbContext.SaveChangesAsync();
        }

        public virtual IQueryable<T> GetQueryable(
          Expression<Func<T, bool>>? filter = null,
          string? includeProperties = null,
          Func<IQueryable<T>, IOrderedQueryable<T>>? orderBy = null)
        {
            IQueryable<T> query = _dbSet;

            if (filter != null)
            {
                query = query.Where(filter);
            }

            if (!string.IsNullOrWhiteSpace(includeProperties))
            {
                foreach (var includeProperty in includeProperties.Split(',', StringSplitOptions.RemoveEmptyEntries))
                {
                    query = query.Include(includeProperty);
                }
            }

            if (orderBy != null)
            {
                query = orderBy(query);
            }

            return query;
        }

        public async Task<bool> AnyAsync(Expression<Func<T, bool>> predicate)
        {
            return await _dbSet.AnyAsync(predicate);
        }

        public IDbContextTransaction BeginTransaction() =>
          _dbContext.Database.BeginTransaction();

        public void Commit() =>
            _dbContext.Database.CommitTransaction();

        public void RollBack() =>
            _dbContext.Database.RollbackTransaction();
    }
}
