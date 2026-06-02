class TripRequestModel {
  final String userId;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final String startAddress;
  final String endAddress;
  final double distance;

  TripRequestModel({
    required this.userId,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.distance,
    required this.startAddress,
    required this.endAddress,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'startLat': startLat,
    'startLng': startLng,
    'endLat': endLat,
    'endLng': endLng,
    'startAddress': startAddress,
    'endAddress': endAddress,
    'distance': distance,
  };
}
