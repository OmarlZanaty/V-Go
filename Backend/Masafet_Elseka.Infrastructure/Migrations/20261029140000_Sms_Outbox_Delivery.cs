using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class Sms_Outbox_Delivery : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DeliveryStatus",
                table: "SmsOutbox",
                type: "nvarchar(24)",
                maxLength: 24,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DeliveryReportAt",
                table: "SmsOutbox",
                type: "datetime2",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "DeliveryStatus", table: "SmsOutbox");
            migrationBuilder.DropColumn(name: "DeliveryReportAt", table: "SmsOutbox");
        }
    }
}
