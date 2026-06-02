class LocationModel {
  final double latitude;
  final double longitude;
  final double? heading; // 0-360 degrees from North, null if unavailable
  final double? accuracy; // in meters
  final double? speed; // in meters/second

  LocationModel({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.accuracy,
    this.speed,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: json['latitude'],
      longitude: json['longitude'],
      heading: json['heading'],
      accuracy: json['accuracy'],
      speed: json['speed'],
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (heading != null) 'heading': heading,
    if (accuracy != null) 'accuracy': accuracy,
    if (speed != null) 'speed': speed,
  };
}
