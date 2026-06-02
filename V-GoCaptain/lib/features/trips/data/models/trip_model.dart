/// A trip as returned by the backend (Trip/tripByUserId, Trip/cuurentTrips).
class TripModel {
  final String tripId;
  final TripPlace from;
  final TripPlace to;
  final double price;
  final double distanceKm;
  final String status; // Pending, Accepted, Arrived, InProgress, Completed, Canceled
  final bool isPaid;
  final String clientName;
  final String clientPhone;
  final String? clientImage;
  final DateTime? createdAt;

  TripModel({
    required this.tripId,
    required this.from,
    required this.to,
    required this.price,
    required this.distanceKm,
    required this.status,
    required this.isPaid,
    required this.clientName,
    required this.clientPhone,
    this.clientImage,
    this.createdAt,
  });

  bool get isCompleted => status == 'Completed';
  bool get isCanceled => status == 'Canceled';
  bool get isActive =>
      status == 'Accepted' || status == 'Arrived' || status == 'InProgress';

  factory TripModel.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    return TripModel(
      tripId: j['tripId']?.toString() ?? '',
      from: TripPlace.fromJson(j['from'] as Map<String, dynamic>? ?? const {}),
      to: TripPlace.fromJson(j['to'] as Map<String, dynamic>? ?? const {}),
      price: d(j['price']),
      distanceKm: d(j['distanceKm']),
      status: j['status']?.toString() ?? '',
      isPaid: j['isPaid'] == true,
      clientName: j['userName']?.toString() ?? 'عميل',
      clientPhone: j['userPhone']?.toString() ?? '',
      clientImage: j['userProfileImage']?.toString(),
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
    );
  }
}

class TripPlace {
  final double lat;
  final double lng;
  final String? address;

  TripPlace({required this.lat, required this.lng, this.address});

  factory TripPlace.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    return TripPlace(
      lat: d(j['lat']),
      lng: d(j['lng']),
      address: j['address']?.toString(),
    );
  }
}
