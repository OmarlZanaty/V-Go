import '../../../features/trips/data/model/trip_model.dart';

class CurrentTripModel {
  final String tripId;
  final String tripStatus;
  final double price;
  final TripLocationModel from;
  final TripLocationModel to;
  final String clientId;
  final String? driverId;
  final String clientName;
  final String driverName;
  final String clientPhone;
  final String driverPhone;
  final String? scooterType;
  final String? scooterLicense;
  final String? clientImageUrl;
  final String? driverImageUrl;
  final num? clientRate;
  final num? driverRate;
  final DateTime createdAt;
  final bool isPaid;
  final String paymentMethod;
  final bool isFreeRide;

  /// Offer discount paid by the company; the rider pays [riderPrice].
  final double discountAmount;
  double get riderPrice =>
      isFreeRide ? 0 : (price - discountAmount).clamp(0, price).toDouble();

  CurrentTripModel({
    required this.tripId,
    required this.tripStatus,
    required this.price,
    required this.from,
    required this.to,
    required this.clientId,
    required this.driverId,
    required this.clientName,
    required this.driverName,
    required this.clientPhone,
    required this.driverPhone,
    required this.createdAt,
    required this.scooterType,
    this.clientImageUrl,
    this.driverImageUrl,
    this.scooterLicense,
    this.clientRate = 0.0,
    this.driverRate = 0.0,
    this.isPaid = false,
    this.paymentMethod = 'Cash',
    this.isFreeRide = false,
    this.discountAmount = 0,
  });

  factory CurrentTripModel.fromJson(Map<String, dynamic> json) {
    final isFreeRide =
        (json['isFreeRide'] ?? json['IsFreeRide'] ?? false) == true;
    return CurrentTripModel(
        tripId: json['tripId'],
        tripStatus: json['status'],
        price: ((json['price'] ?? json['Price'] ?? 0) as num).toDouble(),
        from: TripLocationModel.fromJson(json['from']),
        to: TripLocationModel.fromJson(json['to']),
        clientId: json['userId'],
        driverId: json['driverId'],
        clientName: json['userName'],
        driverName: json['driverName'],
        clientPhone: (json['userPhone'] ?? '').toString(),
        driverPhone: (json['driverPhone'] ?? json['DriverPhone'] ?? '').toString(),
        clientImageUrl: json['userProfileImage'],
        driverImageUrl:
            (json['driverProfileImage'] ?? json['DriverProfileImage'])
                ?.toString(),
        clientRate: json['userrating'],
        driverRate: json['driverRating'],
        scooterType: json['scooterType'],
        scooterLicense: json['scooterLicense'],
        createdAt: DateTime.parse(json['createdAt']),
        isPaid: (json['isPaid'] ?? json['IsPaid'] ?? false) == true,
        paymentMethod:
            (json['paymentMethod'] ?? json['PaymentMethod'] ?? 'Cash')
                .toString(),
        isFreeRide: isFreeRide,
        discountAmount:
            ((json['discountAmount'] ?? json['DiscountAmount'] ?? 0) as num)
                .toDouble(),
      );
  }
}
