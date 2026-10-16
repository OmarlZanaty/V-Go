using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class Promotions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "DiscountAmount",
                table: "Trips",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "PromotionId",
                table: "Trips",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Promotions",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Title = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Type = table.Column<int>(type: "int", nullable: false),
                    Value = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    MaxDiscount = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    Audience = table.Column<int>(type: "int", nullable: false),
                    Code = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: true),
                    RidesPerRider = table.Column<int>(type: "int", nullable: false),
                    RiderLimit = table.Column<int>(type: "int", nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    StartsAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    EndsAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Promotions", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PromotionGrants",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PromotionId = table.Column<int>(type: "int", nullable: false),
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    GrantedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PromotionGrants", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PromotionGrants_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PromotionGrants_Promotions_PromotionId",
                        column: x => x.PromotionId,
                        principalTable: "Promotions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Trips_PromotionId",
                table: "Trips",
                column: "PromotionId");

            migrationBuilder.CreateIndex(
                name: "IX_PromotionGrants_PromotionId_UserId",
                table: "PromotionGrants",
                columns: new[] { "PromotionId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PromotionGrants_UserId",
                table: "PromotionGrants",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Promotions_Code",
                table: "Promotions",
                column: "Code",
                unique: true,
                filter: "[Code] IS NOT NULL");

            migrationBuilder.AddForeignKey(
                name: "FK_Trips_Promotions_PromotionId",
                table: "Trips",
                column: "PromotionId",
                principalTable: "Promotions",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            // The free-rides offer (settings on PricingRules, grants on users) becomes
            // promotion #1, with the same state, riders and past free trips.
            migrationBuilder.Sql(@"
DECLARE @enabled bit, @per int, @limit int;
SELECT TOP 1 @enabled = FreeRidesEnabled, @per = FreeRidesPerRider, @limit = FreeRidesRiderLimit
FROM PricingRules ORDER BY Id;
SET @per = CASE WHEN ISNULL(@per, 0) < 1 THEN 2 ELSE @per END;

INSERT INTO Promotions (Title, Description, Type, Value, MaxDiscount, Audience, Code,
    RidesPerRider, RiderLimit, IsActive, StartsAt, EndsAt, CreatedAt, UpdatedAt)
VALUES (
    CASE @per WHEN 1 THEN N'أول رحلة مجانًا' WHEN 2 THEN N'أول رحلتين مجانًا'
        ELSE CONCAT(N'أول ', @per, N' رحلات مجانًا') END,
    N'هدية من V-Go للعملاء الجدد: الرحلة على حساب الشركة بالكامل.',
    1, 0, NULL, 1, NULL, @per, NULLIF(ISNULL(@limit, 100), 0), ISNULL(@enabled, 0), NULL, NULL, SYSDATETIME(), NULL);

DECLARE @id int = SCOPE_IDENTITY();

INSERT INTO PromotionGrants (PromotionId, UserId, GrantedAt)
SELECT @id, Id, SYSDATETIME() FROM AspNetUsers WHERE FreeRidesGranted > 0;

UPDATE Trips SET PromotionId = @id, DiscountAmount = Price WHERE IsFreeRide = 1;
");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Trips_Promotions_PromotionId",
                table: "Trips");

            migrationBuilder.DropTable(
                name: "PromotionGrants");

            migrationBuilder.DropTable(
                name: "Promotions");

            migrationBuilder.DropIndex(
                name: "IX_Trips_PromotionId",
                table: "Trips");

            migrationBuilder.DropColumn(
                name: "DiscountAmount",
                table: "Trips");

            migrationBuilder.DropColumn(
                name: "PromotionId",
                table: "Trips");
        }
    }
}
