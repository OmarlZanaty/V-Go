using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class Home_Banner_Ad_Slots : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ClickCount",
                table: "HomeBanners",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "CreatedAt",
                table: "HomeBanners",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<DateTime>(
                name: "EndsAt",
                table: "HomeBanners",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsActive",
                table: "HomeBanners",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "LinkUrl",
                table: "HomeBanners",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "StartsAt",
                table: "HomeBanners",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Title",
                table: "HomeBanners",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "HomeBanners",
                type: "datetime2",
                nullable: true);
            // Banners from before (never shown in the app) stay hidden; give them a real date.
            migrationBuilder.Sql("UPDATE [HomeBanners] SET [CreatedAt] = GETDATE()");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ClickCount",
                table: "HomeBanners");

            migrationBuilder.DropColumn(
                name: "CreatedAt",
                table: "HomeBanners");

            migrationBuilder.DropColumn(
                name: "EndsAt",
                table: "HomeBanners");

            migrationBuilder.DropColumn(
                name: "IsActive",
                table: "HomeBanners");

            migrationBuilder.DropColumn(
                name: "LinkUrl",
                table: "HomeBanners");

            migrationBuilder.DropColumn(
                name: "StartsAt",
                table: "HomeBanners");

            migrationBuilder.DropColumn(
                name: "Title",
                table: "HomeBanners");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "HomeBanners");
        }
    }
}
