using Masafet_Elseka.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Masafet_Elseka.Infrastructure.Configurations
{
    public class AppSettingConfiguration : IEntityTypeConfiguration<AppSetting>
    {
        public void Configure(EntityTypeBuilder<AppSetting> builder)
        {
            builder.HasKey(s => s.Key);
            builder.Property(s => s.Key).HasMaxLength(100).ValueGeneratedNever();
            builder.Property(s => s.Value).HasMaxLength(2000).IsRequired();
        }
    }
}
