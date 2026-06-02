import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/repo/auth_repo.dart';
import '../../features/auth/data/repo/auth_repo_impl.dart';
import '../../features/map/data/repo/map_repo.dart';
import '../../features/trips/data/repo/trip_repo.dart';
import '../../features/trips/data/repo/trip_repo_impl.dart';
import '../api/api_service.dart';
import '../api/dio_factory.dart';
import '../services/chat_service.dart';
import '../services/driver_service.dart';
import '../services/firebase_notification_service.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../services/rating_service.dart';
import '../services/trip_service.dart';
import '../utils/repo/chat_repo/chat_repo.dart';
import '../utils/repo/chat_repo/chat_repo_impl.dart';
import '../utils/repo/driver_repo/driver_repo.dart';
import '../utils/repo/payment_repo/payment_repo.dart';
import '../utils/repo/statistics_repo/statistics_repo.dart';
import '../utils/repo/statistics_repo/statistics_repo_impl.dart';
import '../utils/repo/user_repo/user_repo.dart';
import '../utils/repo/user_repo/user_repo_impl.dart';

final getIt = GetIt.instance;

void setupGetIt() {
  // Dio & ApiServices
  final Dio dio = DioFactory.getDio();
  final Dio mapDio = DioUtil.instance;
  getIt.registerLazySingleton<ApiServices>(() => ApiServices(dio: dio));
  // Auth Repository
  getIt.registerLazySingleton<AuthRepo>(
    () => AuthRepoImpl(apiServices: getIt<ApiServices>()),
  );
  // user Repository
  getIt.registerLazySingleton<UserRepo>(
    () => UserRepoImpl(apiServices: getIt<ApiServices>()),
  );
  // trip Repository
  getIt.registerLazySingleton<TripRepo>(
    () => TripRepoImpl(apiServices: getIt<ApiServices>()),
  );
  // trip service
  getIt.registerFactory<TripService>(TripService.new);
  // driver service
  getIt.registerLazySingleton<DriverService>(DriverService.new);
  // location service
  getIt.registerLazySingleton<LocationService>(LocationService.new);
  // chat service
  getIt.registerLazySingleton<ChatService>(ChatService.new);
  // statistics repo
  getIt.registerLazySingleton<StatisticsRepo>(
    () => StatisticsRepoImpl(apiServices: getIt<ApiServices>()),
  );
  // chat repo
  getIt.registerLazySingleton<ChatRepo>(
    () => ChatRepoImpl(apiServices: getIt<ApiServices>()),
  );
  // map service
  getIt.registerLazySingleton<MapService>(() => MapService(mapDio));
  // map repo
  getIt.registerLazySingleton<MapRepo>(
    () => MapRepo(locationService: getIt(), mapService: getIt()),
  );
  // driver repo
  getIt.registerLazySingleton<DriverRepo>(() => DriverRepo(getIt(), getIt()));
  // rating service
  getIt.registerLazySingleton<RatingService>(RatingService.new);
  //payment repo
  getIt.registerLazySingleton<PaymentRepo>(() => PaymentRepo(getIt()));
  //firebase notification service
  getIt.registerLazySingleton(FirebaseNotificationService.new);
}
