using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    // Free rides promo: the first riders who sign up get their first rides free,
    // and the company pays the captain his share.
    public partial class FreeRidesPromo : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "FreeRidesEnabled",
                table: "PricingRules",
                type: "bit",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<int>(
                name: "FreeRidesPerRider",
                table: "PricingRules",
                type: "int",
                nullable: false,
                defaultValue: 2);

            migrationBuilder.AddColumn<int>(
                name: "FreeRidesRiderLimit",
                table: "PricingRules",
                type: "int",
                nullable: false,
                defaultValue: 100);

            migrationBuilder.AddColumn<int>(
                name: "FreeRidesGranted",
                table: "AspNetUsers",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<bool>(
                name: "IsFreeRide",
                table: "Trips",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "FreeRidesEnabled", table: "PricingRules");
            migrationBuilder.DropColumn(name: "FreeRidesPerRider", table: "PricingRules");
            migrationBuilder.DropColumn(name: "FreeRidesRiderLimit", table: "PricingRules");
            migrationBuilder.DropColumn(name: "FreeRidesGranted", table: "AspNetUsers");
            migrationBuilder.DropColumn(name: "IsFreeRide", table: "Trips");
        }
    }
}
