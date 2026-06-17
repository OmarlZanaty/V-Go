/// Incoming trip offer pushed by the backend (TripOfferDTO) over the trip hub
/// via `RecievePendingTrips` / `ReceiveNewTrip`. Parsed defensively because
/// SignalR may deliver camelCase or PascalCase keys.
class TripOfferModel {
  final String tripId;
  final TripPoint start;
  final TripPoint end;
  final double price;
  final TripClient client;
  final String paymentMethod;

  TripOfferModel({
    required this.tripId,
    required this.start,
    required this.end,
    required this.price,
    required this.client,
    this.paymentMethod = 'Cash',
  });

  bool get isVisa => paymentMethod.toLowerCase() == 'visa';

  static dynamic _pick(Map map, String camel, String pascal) =>
      map[camel] ?? map[pascal];

  factory TripOfferModel.fromMap(Map<dynamic, dynamic> map) {
    return TripOfferModel(
      tripId: _pick(map, 'tripId', 'TripId')?.toString() ?? '',
      start: TripPoint.fromMap(
        (_pick(map, 'startLocation', 'StartLocation') as Map?) ?? const {},
      ),
      end: TripPoint.fromMap(
        (_pick(map, 'endLocation', 'EndLocation') as Map?) ?? const {},
      ),
      price: _toDouble(_pick(map, 'price', 'Price')),
      client: TripClient.fromMap(
        (_pick(map, 'client', 'Client') as Map?) ?? const {},
      ),
      paymentMethod:
          _pick(map, 'paymentMethod', 'PaymentMethod')?.toString() ?? 'Cash',
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class TripPoint {
  final double lat;
  final double lng;
  final String address;

  TripPoint({required this.lat, required this.lng, required this.address});

  /// Address to show in the UI — falls back to coordinates when the backend
  /// didn't supply a human-readable address, so the row is never blank.
  String get displayAddress => address.trim().isNotEmpty
      ? address
      : '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

  factory TripPoint.fromMap(Map<dynamic, dynamic> map) {
    return TripPoint(
      lat: TripOfferModel._toDouble(map['lat'] ?? map['Lat']),
      lng: TripOfferModel._toDouble(map['lng'] ?? map['Lng']),
      address: (map['address'] ?? map['Address'])?.toString() ?? '',
    );
  }
}

class TripClient {
  final String clientId;
  final String fullName;
  final String phoneNumber;
  final String? profileImageUrl;
  final double rating;

  TripClient({
    required this.clientId,
    required this.fullName,
    required this.phoneNumber,
    required this.profileImageUrl,
    required this.rating,
  });

  factory TripClient.fromMap(Map<dynamic, dynamic> map) {
    return TripClient(
      clientId: (map['clientId'] ?? map['ClientId'])?.toString() ?? '',
      fullName: (map['fullName'] ?? map['FullName'])?.toString() ?? 'عميل',
      phoneNumber: (map['phoneNumber'] ?? map['PhoneNumber'])?.toString() ?? '',
      profileImageUrl:
          (map['profileImageUrl'] ?? map['ProfileImageUrl'])?.toString(),
      rating: TripOfferModel._toDouble(map['rating'] ?? map['Rating']),
    );
  }
}
