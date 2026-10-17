using Masafet_Elseka.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Masafet_Elseka.Infrastructure.Configurations
{
    public class BetaTesterConfiguration : IEntityTypeConfiguration<BetaTester>
    {
        public void Configure(EntityTypeBuilder<BetaTester> builder)
        {
            builder.HasKey(t => t.Id);
            builder.Property(t => t.Id).HasMaxLength(32).ValueGeneratedNever();
            builder.Property(t => t.Email).HasMaxLength(254).IsRequired();
            builder.HasIndex(t => t.Email).IsUnique();
            builder.Property(t => t.GoogleSub).HasMaxLength(255);
            builder.Property(t => t.Source).HasMaxLength(40).IsRequired();
            builder.Property(t => t.PlayError).HasMaxLength(200);
            builder.HasIndex(t => new { t.PlaySynced, t.EnrolledAt });
        }
    }
}
