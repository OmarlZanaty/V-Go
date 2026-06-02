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
    public class UserConfiguration:IEntityTypeConfiguration<ApplicationUser>
    {
        public void Configure(EntityTypeBuilder<ApplicationUser> builder)
        {
            builder.ToTable("ApplicationUsers");

            builder.HasOne(u => u.Scooter)
                .WithOne(s => s.Driver)
                .HasForeignKey<Scooter>(s => s.DriverId)
                .OnDelete(DeleteBehavior.Cascade);

            builder.HasMany(u => u.Notifications)
                .WithOne(t => t.User)
                .HasForeignKey(t => t.UserId)
                .OnDelete(DeleteBehavior.Cascade);  

            builder.HasMany(u => u.UserDevices)
                 .WithOne(d => d.User)
                 .HasForeignKey(d => d.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
