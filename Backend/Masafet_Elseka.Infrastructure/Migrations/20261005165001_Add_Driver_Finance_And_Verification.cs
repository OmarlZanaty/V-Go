using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class Add_Driver_Finance_And_Verification : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "CashLimit",
                table: "PricingRules",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 1000m);

            migrationBuilder.AddColumn<DateTime>(
                name: "LedgerStartAt",
                table: "PricingRules",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "WarningPercent",
                table: "PricingRules",
                type: "int",
                nullable: false,
                defaultValue: 80);

            migrationBuilder.AddColumn<int>(
                name: "Purpose",
                table: "Payments",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "DocumentsDeadline",
                table: "AspNetUsers",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PayoutAccount",
                table: "AspNetUsers",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PayoutAccountName",
                table: "AspNetUsers",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PayoutMethod",
                table: "AspNetUsers",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "PayoutUpdatedAt",
                table: "AspNetUsers",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "VerificationNote",
                table: "AspNetUsers",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "VerificationStatus",
                table: "AspNetUsers",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "AdminAuditLogs",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ActorUserId = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ActorName = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Action = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    TargetUserId = table.Column<string>(type: "nvarchar(450)", nullable: true),
                    Details = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdminAuditLogs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "DriverDocuments",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    DriverId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Type = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    FilePath = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    IsPublic = table.Column<bool>(type: "bit", nullable: false),
                    ExpiryDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RejectionReason = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    UploadedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ReviewedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ReviewedByUserId = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DriverDocuments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DriverDocuments_AspNetUsers_DriverId",
                        column: x => x.DriverId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "DriverLedgerEntries",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DriverId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Type = table.Column<int>(type: "int", nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    TripId = table.Column<string>(type: "nvarchar(450)", nullable: true),
                    TripFare = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    CommissionPercent = table.Column<decimal>(type: "decimal(5,2)", nullable: true),
                    CommissionAmount = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    PaymentId = table.Column<string>(type: "nvarchar(450)", nullable: true),
                    Description = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Reference = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    AttachmentUrl = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    CreatedByUserId = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DriverLedgerEntries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DriverLedgerEntries_AspNetUsers_DriverId",
                        column: x => x.DriverId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DriverLedgerEntries_Trips_TripId",
                        column: x => x.TripId,
                        principalTable: "Trips",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AspNetUsers_VerificationStatus",
                table: "AspNetUsers",
                column: "VerificationStatus");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_CreatedAt",
                table: "AdminAuditLogs",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_AdminAuditLogs_TargetUserId",
                table: "AdminAuditLogs",
                column: "TargetUserId");

            migrationBuilder.CreateIndex(
                name: "IX_DriverDocuments_DriverId_Type",
                table: "DriverDocuments",
                columns: new[] { "DriverId", "Type" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DriverDocuments_Status",
                table: "DriverDocuments",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_DriverLedgerEntries_DriverId_CreatedAt",
                table: "DriverLedgerEntries",
                columns: new[] { "DriverId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_DriverLedgerEntries_PaymentId",
                table: "DriverLedgerEntries",
                column: "PaymentId",
                unique: true,
                filter: "[PaymentId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_DriverLedgerEntries_TripId",
                table: "DriverLedgerEntries",
                column: "TripId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AdminAuditLogs");

            migrationBuilder.DropTable(
                name: "DriverDocuments");

            migrationBuilder.DropTable(
                name: "DriverLedgerEntries");

            migrationBuilder.DropIndex(
                name: "IX_AspNetUsers_VerificationStatus",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "CashLimit",
                table: "PricingRules");

            migrationBuilder.DropColumn(
                name: "LedgerStartAt",
                table: "PricingRules");

            migrationBuilder.DropColumn(
                name: "WarningPercent",
                table: "PricingRules");

            migrationBuilder.DropColumn(
                name: "Purpose",
                table: "Payments");

            migrationBuilder.DropColumn(
                name: "DocumentsDeadline",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "PayoutAccount",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "PayoutAccountName",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "PayoutMethod",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "PayoutUpdatedAt",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "VerificationNote",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "VerificationStatus",
                table: "AspNetUsers");
        }
    }
}
