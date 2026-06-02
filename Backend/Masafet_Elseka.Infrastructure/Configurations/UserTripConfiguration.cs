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
    public class UserTripConfiguration: IEntityTypeConfiguration<UserTrip>
    {
        public void Configure(EntityTypeBuilder<UserTrip> builder)
        {
            builder.ToTable("UserTrips");
            builder.HasKey(ut => ut.Id);

            builder.HasOne(ut => ut.User)
                .WithMany(u => u.UserTrips)
                .HasForeignKey(ut => ut.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(ut => ut.Trip)
                .WithMany(t => t.UserTrips)
                .HasForeignKey(ut => ut.TripId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
