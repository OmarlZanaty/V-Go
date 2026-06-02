using Masafet_Elseka.Domain.Entities;
using Masafet_Elseka.Infrastructure.Data;
using Masafet_Elseka.Infrastructure.Repositories;
using Microsoft.EntityFrameworkCore.Storage;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.UOW
{
    public class UnitOfWork : IUnitOfWork
    {
        private readonly Context _context;

        public IGenericRepository<ApplicationUser> Users { get; private set; }
        public IGenericRepository<Chat> Chats { get; private set; }
        public IGenericRepository<Message> Message { get; private set; }
        public IGenericRepository<Expense> Expenses { get; private set; }
        public IGenericRepository<Rate> Rates { get; private set; }
        public IGenericRepository<Trip> Trips { get; private set; }
        public IGenericRepository<Scooter> Scooters { get; private set; }
        public IGenericRepository<PricingRule> PricingRules { get; private set; }
        public IGenericRepository<UserChat> UserChats { get; private set; }
        public IGenericRepository<UserTrip> UserTrips { get; private set; }
        public IGenericRepository<UserDevice> UserDevices { get; private set; }
        public IGenericRepository<Notification> Notifications { get; private set; }



        public UnitOfWork(Context context)
        {
            _context = context;

            Users = new GenericRepository<ApplicationUser>(_context);
            Chats = new GenericRepository<Chat>(_context);
            Message = new GenericRepository<Message>(_context);
            Expenses = new GenericRepository<Expense>(_context);
            Rates = new GenericRepository<Rate>(_context);
            Trips = new GenericRepository<Trip>(_context);
            Scooters = new GenericRepository<Scooter>(_context);
            PricingRules = new GenericRepository<PricingRule>(_context);
            UserChats = new GenericRepository<UserChat>(_context);
            UserTrips = new GenericRepository<UserTrip>(_context);
            Notifications = new GenericRepository<Notification>(_context);
            UserDevices = new GenericRepository<UserDevice>(_context);

        }

        public async Task<int> SaveAsync()
        {
            return await _context.SaveChangesAsync();
        }
        public async Task<int> SaveAsync(CancellationToken ct)
        {
            return await _context.SaveChangesAsync();
        }
        public async Task<IDbContextTransaction> BeginTransactionAsync()
        {
            return await _context.Database.BeginTransactionAsync();
        }

        public void Dispose()
        {
            _context.Dispose();
        }
    }
}
