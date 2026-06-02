using Masafet_Elseka.Domain.Entities;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection.Emit;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Data
{
    public class Context:IdentityDbContext<ApplicationUser>
    {
        public Context(DbContextOptions<Context> options):base(options)
        {
        
        }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            builder.ApplyConfigurationsFromAssembly(typeof(Context).Assembly);
            builder.Entity<ApplicationUser>()
                .HasQueryFilter(u => !u.IsDeleted);
                
            builder.Entity<Trip>(entity =>
            {
                entity.HasKey(t => t.Id);
                entity.Property(t => t.Id)
                    .ValueGeneratedOnAdd();  
            });
            builder.Entity<Scooter>(entity =>
            {
                entity.HasKey(t => t.Id);
                entity.Property(t => t.Id)
                    .ValueGeneratedOnAdd();
            });
            base.OnModelCreating(builder);
        }

        public DbSet<ApplicationUser> ApplicationUsers { get; set; }
        public DbSet<Trip> Trips { get; set; }
        public DbSet<Rate> Rates { get; set; }
        public DbSet<Scooter> Scooters { get; set; }
        public DbSet<Expense> Expenses { get; set; }
        public DbSet<Message> Messages { get; set; }
        public DbSet<Chat> Chats { get; set; }
        public DbSet<UserChat> UserChats { get; set; }
        public DbSet<UserTrip> UserTrips { get; set; }
        public DbSet<PricingRule> PricingRules { get; set; }
        public DbSet<Payment> Payments { get; set; }
        public DbSet<SavedCard> SavedCards { get; set; }
        public DbSet<Notification> Notifications { get; set; }
        public DbSet<HomeBanner> HomeBanners { get; set; }

    }
}
