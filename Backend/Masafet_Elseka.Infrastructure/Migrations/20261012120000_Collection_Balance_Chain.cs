using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    // Balance chain (anti-forgery) and dual-SIM collector phones, ported from VIP.
    public partial class Collection_Balance_Chain : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ChainStatus",
                table: "WalletSms",
                type: "int",
                nullable: false,
                defaultValue: 0); // existing rows: NotApplicable

            migrationBuilder.AddColumn<int>(
                name: "SimSlot",
                table: "WalletSms",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SimSlot",
                table: "CollectionWallets",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "ExpectedBalance",
                table: "CollectionWallets",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "GapStreak",
                table: "CollectionWallets",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastChainAt",
                table: "CollectionWallets",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PausedReason",
                table: "CollectionWallets",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PausedAt",
                table: "CollectionWallets",
                type: "datetime2",
                nullable: true);

            // Anchor every wallet on the newest balance it already reported, so the first
            // receipt after the deploy is checked instead of landing in review as "first".
            migrationBuilder.Sql(@"
UPDATE w SET w.ExpectedBalance = s.BalanceAfter, w.LastChainAt = s.ReceivedAt
FROM CollectionWallets w
CROSS APPLY (SELECT TOP 1 x.BalanceAfter, x.ReceivedAt FROM WalletSms x
             WHERE x.WalletId = w.Id AND x.BalanceAfter IS NOT NULL
             ORDER BY x.ReceivedAt DESC, x.Id DESC) s
WHERE w.Provider <> 3;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "ChainStatus", table: "WalletSms");
            migrationBuilder.DropColumn(name: "SimSlot", table: "WalletSms");
            migrationBuilder.DropColumn(name: "SimSlot", table: "CollectionWallets");
            migrationBuilder.DropColumn(name: "ExpectedBalance", table: "CollectionWallets");
            migrationBuilder.DropColumn(name: "GapStreak", table: "CollectionWallets");
            migrationBuilder.DropColumn(name: "LastChainAt", table: "CollectionWallets");
            migrationBuilder.DropColumn(name: "PausedReason", table: "CollectionWallets");
            migrationBuilder.DropColumn(name: "PausedAt", table: "CollectionWallets");
        }
    }
}
