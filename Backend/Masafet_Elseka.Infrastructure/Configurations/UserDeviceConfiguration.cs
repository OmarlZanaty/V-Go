using Masafet_Elseka.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

public class UserDeviceConfiguration : IEntityTypeConfiguration<UserDevice>
{
    public void Configure(EntityTypeBuilder<UserDevice> builder)
    {
        builder.HasKey(d => d.Id);

        builder.Property(d => d.DeviceToken)
            .IsRequired();

        builder.HasIndex(d => d.DeviceToken)
            .IsUnique();

        builder.Property(d => d.DeviceType)
            .HasMaxLength(50);

        builder.Property(d => d.LastActive)
            .HasDefaultValueSql("GETUTCDATE()");
    }
}
