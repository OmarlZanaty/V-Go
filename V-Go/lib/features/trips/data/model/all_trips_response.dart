import 'trip_model.dart';

class AllTripsResponse {
  final List<TripModel> trips;
  final bool hasNextPage;

  AllTripsResponse({required this.trips, required this.hasNextPage});

  factory AllTripsResponse.fromJson(Map<String, dynamic> json) =>
      AllTripsResponse(
        trips: json['data']
            .map<TripModel>((e) => TripModel.fromJson(e))
            .toList(),
        hasNextPage: json['hasNextPage'],
      );
}
