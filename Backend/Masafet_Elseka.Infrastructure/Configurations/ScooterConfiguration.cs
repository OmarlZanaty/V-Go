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
    public class ScooterConfiguration:IEntityTypeConfiguration<Scooter>
    {
        public void Configure(EntityTypeBuilder<Scooter> builder)
        {
            builder.ToTable("Scooters");
            builder.HasKey(s => s.Id);

            builder.Property(s => s.License)
                .IsRequired(false).HasMaxLength(20);

            builder.HasOne(s => s.Driver)
                .WithOne(u => u.Scooter)
                .HasForeignKey<Scooter>(s => s.DriverId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
