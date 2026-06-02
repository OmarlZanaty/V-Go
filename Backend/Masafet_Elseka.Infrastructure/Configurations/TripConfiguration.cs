using Masafet_Elseka.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.Configurations
{
    public class TripConfiguration : IEntityTypeConfiguration<Trip>
    {
        public void Configure(EntityTypeBuilder<Trip> builder)
        {
            builder.ToTable("Trips");

            builder.HasKey(t => t.Id);

            builder.Property(t => t.Price)
                   .HasColumnType("decimal(10,2)");

            builder.Property(t => t.StartLat)
                   .IsRequired();
            builder.Property(t => t.StartLng)
                   .IsRequired();

            builder.Property(t => t.EndLat)
                   .IsRequired();
            builder.Property(t => t.EndLat)
                   .IsRequired();

            builder.Property(t => t.CreatedAt)
                   .HasDefaultValueSql("GETDATE()");

            builder.Property(t => t.Status)
                   .IsRequired();

            builder.HasMany(t => t.UserRates)
                   .WithOne(r => r.Trip)
                   .HasForeignKey(r => r.TripId)
                   .OnDelete(DeleteBehavior.Cascade);

            builder.HasMany(t => t.UserTrips)
                   .WithOne(r => r.Trip)
                   .HasForeignKey(r => r.TripId)
                   .OnDelete(DeleteBehavior.Cascade);

            builder.HasOne(t => t.Chat)
                     .WithOne(c => c.Trip)
                     .IsRequired(false)
                     .HasForeignKey<Chat>(c => c.TripId)
                     .IsRequired(false)
                     .OnDelete(DeleteBehavior.Cascade);
        }
    }

}
