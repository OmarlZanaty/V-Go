using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Repositories;
using Microsoft.EntityFrameworkCore.Storage;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.UOW
{
    public interface IUnitOfWork:IDisposable
    {
        IGenericRepository<ApplicationUser> Users { get; }
        IGenericRepository<Chat> Chats { get; }
        IGenericRepository<Message> Message { get; }
        IGenericRepository<Expense> Expenses { get; }
        IGenericRepository<Rate> Rates { get; }
        IGenericRepository<Trip> Trips { get; }
        IGenericRepository<Scooter> Scooters { get; }
        IGenericRepository<PricingRule> PricingRules { get; }
        IGenericRepository<UserChat> UserChats { get; }
        IGenericRepository<UserTrip> UserTrips { get; }
        IGenericRepository<UserDevice> UserDevices { get; }
        IGenericRepository<Notification> Notifications { get; }


        Task<int> SaveAsync();
        Task<int> SaveAsync(CancellationToken ct);
        Task<IDbContextTransaction> BeginTransactionAsync();
    }
}
