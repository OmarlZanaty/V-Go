class TripModel {
  final String tripId;
  final TripLocationModel from;
  final TripLocationModel to;
  final double price;
  final double distanceKm;
  final String status;
  final String userId;
  final String userName;
  final String userPhone;
  final String? userImageUrl;
  final String? driverImageUrl;
  final num? userRate;
  final num? driverRate;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final DateTime createdAt;

  TripModel({
    required this.tripId,
    required this.from,
    required this.to,
    required this.price,
    required this.distanceKm,
    required this.status,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.createdAt,
    this.userImageUrl,
    this.driverImageUrl,
    this.userRate = 0.0,
    this.driverRate = 0.0,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      tripId: json['tripId'] as String,
      from: TripLocationModel.fromJson(json['from']),
      to: TripLocationModel.fromJson(json['to']),
      price: (json['price'] as num).toDouble(),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      status: json['status'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userPhone: json['userPhone'] as String,
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      driverPhone: json['driverPhone'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userImageUrl: json['userProfileImage'] as String?,
      driverImageUrl: json['driverProfileImage'] as String?,
      userRate: json['userrating'] ?? 0.0,
      driverRate: json['driverRating'] ?? 0.0,
    );
  }
}

class TripLocationModel {
  final double lat;
  final double lng;
  final String address;
  TripLocationModel({
    required this.lat,
    required this.lng,
    required this.address,
  });

  factory TripLocationModel.fromJson(Map<String, dynamic> json) {
    return TripLocationModel(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] ?? 'غير متوفر',
    );
  }

  Map<String, dynamic> toJson() {
    return {'lat': lat, 'lng': lng, 'address': address};
  }
}
