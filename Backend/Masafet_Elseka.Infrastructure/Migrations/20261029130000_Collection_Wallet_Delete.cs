using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class Collection_Wallet_Delete : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAt",
                table: "CollectionWallets",
                type: "datetime2",
                nullable: true);

            migrationBuilder.DropIndex(
                name: "IX_CollectionWallets_Provider_PhoneNumber",
                table: "CollectionWallets");

            migrationBuilder.CreateIndex(
                name: "IX_CollectionWallets_Provider_PhoneNumber",
                table: "CollectionWallets",
                columns: new[] { "Provider", "PhoneNumber" },
                unique: true,
                filter: "[DeletedAt] IS NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_CollectionWallets_Provider_PhoneNumber",
                table: "CollectionWallets");

            migrationBuilder.DropColumn(name: "DeletedAt", table: "CollectionWallets");

            migrationBuilder.CreateIndex(
                name: "IX_CollectionWallets_Provider_PhoneNumber",
                table: "CollectionWallets",
                columns: new[] { "Provider", "PhoneNumber" },
                unique: true);
        }
    }
}
