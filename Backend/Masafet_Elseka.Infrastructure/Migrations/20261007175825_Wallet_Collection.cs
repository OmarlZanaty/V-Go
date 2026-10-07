using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class Wallet_Collection : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "CollectionDeadlineHour",
                table: "PricingRules",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<bool>(
                name: "CollectionEnabled",
                table: "PricingRules",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "CollectionNoticeHour",
                table: "PricingRules",
                type: "int",
                nullable: false,
                defaultValue: 20);

            migrationBuilder.AddColumn<decimal>(
                name: "CollectionTolerance",
                table: "PricingRules",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 50m);

            migrationBuilder.AddColumn<long>(
                name: "WalletSmsId",
                table: "DriverLedgerEntries",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CollectionLockedAt",
                table: "AspNetUsers",
                type: "datetime2",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "CollectionCycles",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CycleDate = table.Column<DateTime>(type: "date", nullable: false),
                    NoticeSentAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    NoticeCount = table.Column<int>(type: "int", nullable: false),
                    ReminderSentAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ReminderCount = table.Column<int>(type: "int", nullable: false),
                    LockAppliedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LockedCount = table.Column<int>(type: "int", nullable: false),
                    LockNote = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CollectionCycles", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "CollectorDevices",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    KeyHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    PairingCode = table.Column<string>(type: "nvarchar(12)", maxLength: 12, nullable: true),
                    PairingExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    PairedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LastSeenAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    AppVersion = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: true),
                    LastStatus = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedByUserId = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CollectorDevices", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "CollectionWallets",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Provider = table.Column<int>(type: "int", nullable: false),
                    PhoneNumber = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    HolderName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    DeviceId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    LastSmsAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CollectionWallets", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CollectionWallets_CollectorDevices_DeviceId",
                        column: x => x.DeviceId,
                        principalTable: "CollectorDevices",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "CollectionRequests",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DriverId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    WalletId = table.Column<int>(type: "int", nullable: false),
                    SenderPhone = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    DebtAtRequest = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    WalletSmsId = table.Column<long>(type: "bigint", nullable: true),
                    Note = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ResolvedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ResolvedByUserId = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CollectionRequests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CollectionRequests_AspNetUsers_DriverId",
                        column: x => x.DriverId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CollectionRequests_CollectionWallets_WalletId",
                        column: x => x.WalletId,
                        principalTable: "CollectionWallets",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "WalletSms",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DeviceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ClientId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Sender = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    Body = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    ReceivedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IngestedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Provider = table.Column<int>(type: "int", nullable: true),
                    WalletId = table.Column<int>(type: "int", nullable: true),
                    Kind = table.Column<int>(type: "int", nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    CounterpartyPhone = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    TxnRef = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: true),
                    BalanceAfter = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    MatchStatus = table.Column<int>(type: "int", nullable: false),
                    CollectionRequestId = table.Column<long>(type: "bigint", nullable: true),
                    DriverId = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Note = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    ReviewedByUserId = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ReviewedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WalletSms", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WalletSms_CollectionWallets_WalletId",
                        column: x => x.WalletId,
                        principalTable: "CollectionWallets",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_WalletSms_CollectorDevices_DeviceId",
                        column: x => x.DeviceId,
                        principalTable: "CollectorDevices",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DriverLedgerEntries_WalletSmsId",
                table: "DriverLedgerEntries",
                column: "WalletSmsId",
                unique: true,
                filter: "[WalletSmsId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_CollectionCycles_CycleDate",
                table: "CollectionCycles",
                column: "CycleDate",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CollectionRequests_DriverId_CreatedAt",
                table: "CollectionRequests",
                columns: new[] { "DriverId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_CollectionRequests_Status_SenderPhone",
                table: "CollectionRequests",
                columns: new[] { "Status", "SenderPhone" });

            migrationBuilder.CreateIndex(
                name: "IX_CollectionRequests_WalletId",
                table: "CollectionRequests",
                column: "WalletId");

            migrationBuilder.CreateIndex(
                name: "IX_CollectionWallets_DeviceId",
                table: "CollectionWallets",
                column: "DeviceId");

            migrationBuilder.CreateIndex(
                name: "IX_CollectionWallets_Provider_PhoneNumber",
                table: "CollectionWallets",
                columns: new[] { "Provider", "PhoneNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CollectorDevices_PairingCode",
                table: "CollectorDevices",
                column: "PairingCode",
                unique: true,
                filter: "[PairingCode] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_WalletSms_DeviceId_ClientId",
                table: "WalletSms",
                columns: new[] { "DeviceId", "ClientId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_WalletSms_MatchStatus_CounterpartyPhone",
                table: "WalletSms",
                columns: new[] { "MatchStatus", "CounterpartyPhone" });

            migrationBuilder.CreateIndex(
                name: "IX_WalletSms_Provider_TxnRef",
                table: "WalletSms",
                columns: new[] { "Provider", "TxnRef" },
                unique: true,
                filter: "[TxnRef] IS NOT NULL AND [Provider] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_WalletSms_ReceivedAt",
                table: "WalletSms",
                column: "ReceivedAt");

            migrationBuilder.CreateIndex(
                name: "IX_WalletSms_WalletId",
                table: "WalletSms",
                column: "WalletId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CollectionCycles");

            migrationBuilder.DropTable(
                name: "CollectionRequests");

            migrationBuilder.DropTable(
                name: "WalletSms");

            migrationBuilder.DropTable(
                name: "CollectionWallets");

            migrationBuilder.DropTable(
                name: "CollectorDevices");

            migrationBuilder.DropIndex(
                name: "IX_DriverLedgerEntries_WalletSmsId",
                table: "DriverLedgerEntries");

            migrationBuilder.DropColumn(
                name: "CollectionDeadlineHour",
                table: "PricingRules");

            migrationBuilder.DropColumn(
                name: "CollectionEnabled",
                table: "PricingRules");

            migrationBuilder.DropColumn(
                name: "CollectionNoticeHour",
                table: "PricingRules");

            migrationBuilder.DropColumn(
                name: "CollectionTolerance",
                table: "PricingRules");

            migrationBuilder.DropColumn(
                name: "WalletSmsId",
                table: "DriverLedgerEntries");

            migrationBuilder.DropColumn(
                name: "CollectionLockedAt",
                table: "AspNetUsers");
        }
    }
}
