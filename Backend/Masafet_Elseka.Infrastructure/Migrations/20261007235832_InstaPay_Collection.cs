using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Masafet_Elseka.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class InstaPay_Collection : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CounterpartyAccount",
                table: "WalletSms",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CounterpartyName",
                table: "WalletSms",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Source",
                table: "WalletSms",
                type: "int",
                nullable: false,
                defaultValue: 1); // existing rows are SMS

            migrationBuilder.AddColumn<string>(
                name: "SourcePackage",
                table: "WalletSms",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "PhoneNumber",
                table: "CollectionWallets",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(20)",
                oldMaxLength: 20);

            migrationBuilder.AddColumn<string>(
                name: "BankName",
                table: "CollectionWallets",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "SenderPhone",
                table: "CollectionRequests",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(20)",
                oldMaxLength: 20);

            migrationBuilder.AddColumn<string>(
                name: "SenderAccount",
                table: "CollectionRequests",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SenderName",
                table: "CollectionRequests",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CounterpartyAccount",
                table: "WalletSms");

            migrationBuilder.DropColumn(
                name: "CounterpartyName",
                table: "WalletSms");

            migrationBuilder.DropColumn(
                name: "Source",
                table: "WalletSms");

            migrationBuilder.DropColumn(
                name: "SourcePackage",
                table: "WalletSms");

            migrationBuilder.DropColumn(
                name: "BankName",
                table: "CollectionWallets");

            migrationBuilder.DropColumn(
                name: "SenderAccount",
                table: "CollectionRequests");

            migrationBuilder.DropColumn(
                name: "SenderName",
                table: "CollectionRequests");

            migrationBuilder.AlterColumn<string>(
                name: "PhoneNumber",
                table: "CollectionWallets",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(100)",
                oldMaxLength: 100);

            migrationBuilder.AlterColumn<string>(
                name: "SenderPhone",
                table: "CollectionRequests",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "nvarchar(20)",
                oldMaxLength: 20,
                oldNullable: true);
        }
    }
}
