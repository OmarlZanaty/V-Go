import 'trip_model.dart';

class NewTripRequestedForDriverModel {
  final String tripId;
  final TripLocationModel startLocation;
  final TripLocationModel endLocation;
  final double price;
  final DateTime createdAt;
  final ClientInfo client;
  final String? tripStatus;

  NewTripRequestedForDriverModel({
    required this.tripId,
    required this.startLocation,
    required this.endLocation,
    required this.price,
    required this.createdAt,
    required this.client,
    this.tripStatus = 'Pending',
  });

  factory NewTripRequestedForDriverModel.fromJson(Map<String, dynamic> json) {
    return NewTripRequestedForDriverModel(
      tripId: json['tripId'],
      startLocation: TripLocationModel.fromJson(json['startLocation']),
      endLocation: TripLocationModel.fromJson(json['endLocation']),
      price: json['price'].toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      client: ClientInfo.fromJson(json['client']),
    );
  }

  NewTripRequestedForDriverModel copyWith({
    String? tripId,
    TripLocationModel? startLocation,
    TripLocationModel? endLocation,
    double? price,
    DateTime? createdAt,
    ClientInfo? client,
    String? tripStatus,
  }) {
    return NewTripRequestedForDriverModel(
      tripId: tripId ?? this.tripId,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      client: client ?? this.client,
      tripStatus: tripStatus ?? this.tripStatus,
    );
  }
}

class ClientInfo {
  final String clientId;
  final String name;
  final String phoneNumber;
  final String? imageUrl;
  final num? clientRate;

  ClientInfo({
    required this.clientId,
    required this.name,
    required this.phoneNumber,
    this.imageUrl,
    this.clientRate = 0,
  });

  factory ClientInfo.fromJson(Map<String, dynamic> json) {
    return ClientInfo(
      clientId: json['clientId'],
      name: json['fullName'],
      phoneNumber: json['phoneNumber'],
      imageUrl: json['profileImageUrl'],
      clientRate: json['rating'] ?? 0.0,
    );
  }
}
