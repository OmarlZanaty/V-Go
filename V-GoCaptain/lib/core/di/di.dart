import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/repo/auth_repo.dart';
import '../../features/auth/data/repo/auth_repo_impl.dart';
import '../../features/profile/data/repo/profile_repo.dart';
import '../../features/profile/data/repo/profile_repo_impl.dart';
import '../../features/trips/data/repo/trip_repo.dart';
import '../../features/trips/data/repo/trip_repo_impl.dart';
import '../api/api_service.dart';
import '../api/dio_factory.dart';
import '../services/location_service.dart';
import '../services/realtime_service.dart';

final getIt = GetIt.instance;

void setupGetIt() {
  // Dio + ApiServices
  final Dio dio = DioFactory.getDio();
  getIt.registerLazySingleton<ApiServices>(() => ApiServices(dio: dio));

  // Auth repository
  getIt.registerLazySingleton<AuthRepo>(
    () => AuthRepoImpl(apiServices: getIt<ApiServices>()),
  );

  // Realtime + location services (driver trip-matching)
  getIt.registerLazySingleton<LocationService>(LocationService.new);
  getIt.registerLazySingleton<RealtimeService>(RealtimeService.new);

  // Trips repository (history + earnings)
  getIt.registerLazySingleton<TripRepo>(
    () => TripRepoImpl(apiServices: getIt<ApiServices>()),
  );

  // Profile repository (scooter data, ratings, support)
  getIt.registerLazySingleton<ProfileRepo>(
    () => ProfileRepoImpl(apiServices: getIt<ApiServices>()),
  );
}
