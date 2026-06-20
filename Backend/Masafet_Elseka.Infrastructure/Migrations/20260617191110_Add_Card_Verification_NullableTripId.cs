using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class Add_Card_Verification_NullableTripId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Payments_Trips_TripId",
                table: "Payments");

            migrationBuilder.AlterColumn<string>(
                name: "TripId",
                table: "Payments",
                type: "nvarchar(450)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(450)");

            migrationBuilder.AddForeignKey(
                name: "FK_Payments_Trips_TripId",
                table: "Payments",
                column: "TripId",
                principalTable: "Trips",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Payments_Trips_TripId",
                table: "Payments");

            migrationBuilder.AlterColumn<string>(
                name: "TripId",
                table: "Payments",
                type: "nvarchar(450)",
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "nvarchar(450)",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Payments_Trips_TripId",
                table: "Payments",
                column: "TripId",
                principalTable: "Trips",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
