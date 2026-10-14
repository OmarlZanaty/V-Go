using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    // The store builds don't know free trips yet (the captain would still collect
    // cash), so the promo stays off until an admin enables it after the release.
    public partial class FreeRidesOffUntilAppRelease : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("UPDATE PricingRules SET FreeRidesEnabled = 0");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
        }
    }
}
