class AdminStatisticsModel {
  final String? clients;
  final String? drivers;
  final String? dispatchers;
  final String? accountants;
  final String? trips;
  final String? kiloPrice;
  final String? driverCommission;

  AdminStatisticsModel({
    this.clients,
    this.drivers,
    this.dispatchers,
    this.accountants,
    this.trips,
    this.kiloPrice,
    this.driverCommission,
  });

  factory AdminStatisticsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatisticsModel(
      clients: (json['Clients'] ?? '0').toString(),
      drivers: (json['Drivers'] ?? '0').toString(),
      dispatchers: (json['Dispatchers'] ?? '0').toString(),
      accountants: (json['Accountants'] ?? '0').toString(),
      trips: (json['Trips'] ?? '0').toString(),
      kiloPrice: (json['KilloPrice'] ?? '0').toString(),
      driverCommission: (json['DriverCommission'] ?? '0').toString(),
    );
  }
}
