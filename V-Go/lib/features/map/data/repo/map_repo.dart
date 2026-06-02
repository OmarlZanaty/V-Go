import '../../../../core/services/location_service.dart';
import '../../../../core/services/map_service.dart';
import '../../../../core/utils/model/edit_distance_result_model.dart';
import '../../../../core/utils/model/location_model.dart';
import '../model/place_suggestion_model.dart';
import '../model/route_result_model.dart';

class MapRepo {
  final LocationService locationService;
  final MapService mapService;

  MapRepo({required this.locationService, required this.mapService});

  Future<LocationModel> getCurrentLocation() async{
    return await locationService.getCurrentLocation();
  }

  Stream<LocationModel> getLocationStream() {
    return locationService.getLocationStream();
  }

  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    return await locationService.getAddressFromCoordinates(latitude, longitude);
  }

  Future<RouteResultModel> getRoute(
    LocationModel from,
    LocationModel to,
  ) async {
    return await mapService.getRouteBetweenLocations(from, to);
  }

  Future<List<PlaceSuggestionModel>> getPlaceSuggestions(
    String query,
    String sessionToken,
  ) async {
    return await mapService.getPlaceSuggestions(query, sessionToken);
  }

  Future<LocationModel> getPlaceLocation(String placeId) async {
    return await mapService.getPlaceLocation(placeId);
  }

  Future<EtaDistanceResult?> getEstimatedTimeOfArrivalWithDistance(
    LocationModel from,
    LocationModel to,
  ) async {
   

    
    final routeResult = await mapService.getEstimatedTimeOfArrival(from, to);
    return routeResult;
  }
}
