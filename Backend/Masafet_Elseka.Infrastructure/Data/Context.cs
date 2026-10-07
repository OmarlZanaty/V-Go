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
            builder.Entity<DriverLedgerEntry>(entity =>
            {
                entity.HasIndex(e => new { e.DriverId, e.CreatedAt });
                entity.HasIndex(e => e.TripId);
                // A Paymob settlement can be credited only once, however many times
                // the webhook / callback / reconcile paths report it.
                entity.HasIndex(e => e.PaymentId).IsUnique().HasFilter("[PaymentId] IS NOT NULL");
                // Same for a wallet receipt SMS: one SMS, one credit.
                entity.HasIndex(e => e.WalletSmsId).IsUnique().HasFilter("[WalletSmsId] IS NOT NULL");
                entity.HasOne(e => e.Driver).WithMany().HasForeignKey(e => e.DriverId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(e => e.Trip).WithMany().HasForeignKey(e => e.TripId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasQueryFilter(e => !e.Driver.IsDeleted);
            });
            builder.Entity<DriverDocument>(entity =>
            {
                entity.HasIndex(d => new { d.DriverId, d.Type }).IsUnique();
                entity.HasIndex(d => d.Status);
                entity.HasOne(d => d.Driver).WithMany(u => u.DriverDocuments).HasForeignKey(d => d.DriverId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasQueryFilter(d => !d.Driver.IsDeleted);
            });
            builder.Entity<AdminAuditLog>(entity =>
            {
                entity.HasIndex(a => a.CreatedAt);
                entity.HasIndex(a => a.TargetUserId);
            });
            builder.Entity<ApplicationUser>().HasIndex(u => u.VerificationStatus);

            // Wallet collection.
            builder.Entity<CollectionWallet>(entity =>
            {
                entity.HasIndex(w => new { w.Provider, w.PhoneNumber }).IsUnique();
                entity.HasOne(w => w.Device).WithMany().HasForeignKey(w => w.DeviceId)
                    .OnDelete(DeleteBehavior.SetNull);
            });
            builder.Entity<CollectorDevice>(entity =>
            {
                entity.HasIndex(d => d.PairingCode).IsUnique().HasFilter("[PairingCode] IS NOT NULL");
            });
            builder.Entity<WalletSms>(entity =>
            {
                // A retried upload of the same message is recognised by its phone-side id...
                entity.HasIndex(s => new { s.DeviceId, s.ClientId }).IsUnique();
                // ...and the same transfer reported twice (another phone, reinstall) by its reference.
                entity.HasIndex(s => new { s.Provider, s.TxnRef }).IsUnique()
                    .HasFilter("[TxnRef] IS NOT NULL AND [Provider] IS NOT NULL");
                entity.HasIndex(s => new { s.MatchStatus, s.CounterpartyPhone });
                entity.HasIndex(s => s.ReceivedAt);
                entity.HasOne(s => s.Device).WithMany().HasForeignKey(s => s.DeviceId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(s => s.Wallet).WithMany().HasForeignKey(s => s.WalletId)
                    .OnDelete(DeleteBehavior.Restrict);
            });
            builder.Entity<CollectionRequest>(entity =>
            {
                entity.HasIndex(r => new { r.Status, r.SenderPhone });
                entity.HasIndex(r => new { r.DriverId, r.CreatedAt });
                entity.HasOne(r => r.Driver).WithMany().HasForeignKey(r => r.DriverId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasOne(r => r.Wallet).WithMany().HasForeignKey(r => r.WalletId)
                    .OnDelete(DeleteBehavior.Restrict);
                entity.HasQueryFilter(r => !r.Driver.IsDeleted);
            });
            builder.Entity<CollectionCycle>(entity =>
            {
                entity.HasIndex(c => c.CycleDate).IsUnique();
                entity.Property(c => c.CycleDate).HasColumnType("date");
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
        public DbSet<DriverLedgerEntry> DriverLedgerEntries { get; set; }
        public DbSet<DriverDocument> DriverDocuments { get; set; }
        public DbSet<AdminAuditLog> AdminAuditLogs { get; set; }
        public DbSet<CollectionWallet> CollectionWallets { get; set; }
        public DbSet<CollectorDevice> CollectorDevices { get; set; }
        public DbSet<WalletSms> WalletSms { get; set; }
        public DbSet<CollectionRequest> CollectionRequests { get; set; }
        public DbSet<CollectionCycle> CollectionCycles { get; set; }

    }
}
