using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class Beta_Enrolment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AppSettings",
                columns: table => new
                {
                    Key = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Value = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AppSettings", x => x.Key);
                });

            migrationBuilder.CreateTable(
                name: "BetaTesters",
                columns: table => new
                {
                    Id = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    Email = table.Column<string>(type: "nvarchar(254)", maxLength: 254, nullable: false),
                    GoogleSub = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    Source = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    PlaySynced = table.Column<bool>(type: "bit", nullable: false),
                    PlayError = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    SyncAttempts = table.Column<int>(type: "int", nullable: false),
                    EnrolledAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastCheckedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RemindedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BetaTesters", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BetaTesters_Email",
                table: "BetaTesters",
                column: "Email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_BetaTesters_PlaySynced_EnrolledAt",
                table: "BetaTesters",
                columns: new[] { "PlaySynced", "EnrolledAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "BetaTesters");
            migrationBuilder.DropTable(name: "AppSettings");
        }
    }
}
