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
  });

  factory CurrentTripModel.fromJson(Map<String, dynamic> json) =>
      CurrentTripModel(
        tripId: json['tripId'],
        tripStatus: json['status'],
        price: json['price'],
        from: TripLocationModel.fromJson(json['from']),
        to: TripLocationModel.fromJson(json['to']),
        clientId: json['userId'],
        driverId: json['driverId'],
        clientName: json['userName'],
        driverName: json['driverName'],
        clientPhone: json['userPhone'],
        driverPhone: json['driverPhone'],
        clientImageUrl: json['userProfileImage'],
        driverImageUrl: json['driverProfileImage'],
        clientRate: json['userrating'],
        driverRate: json['driverRating'],
        scooterType: json['scooterType'],
        scooterLicense: json['scooterLicense'],
        createdAt: DateTime.parse(json['createdAt']),
        isPaid: json['isPaid'],
        paymentMethod: (json['paymentMethod'] ?? 'Cash') as String,
      );
}
