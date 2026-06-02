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
    public class ChatConfiguration:IEntityTypeConfiguration<Chat>
    {
        public void Configure(EntityTypeBuilder<Chat> builder)
        {
            builder.ToTable("Chats");
            builder.HasKey(c => c.Id);

            builder.HasOne(c => c.Trip)
                   .WithOne(t => t.Chat)
                   .IsRequired(false)
                   .HasForeignKey<Chat>(c => c.TripId)
                   .OnDelete(DeleteBehavior.Restrict);

            builder.HasMany(c => c.Messages)
                     .WithOne(m => m.Chat)
                     .HasForeignKey(m => m.ChatId)
                     .OnDelete(DeleteBehavior.Cascade);

            builder.HasMany(c => c.UserChats)
                        .WithOne(uc => uc.Chat)
                        .HasForeignKey(uc => uc.ChatId)
                        .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
