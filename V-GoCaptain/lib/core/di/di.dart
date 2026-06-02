import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/repo/auth_repo.dart';
import '../../features/auth/data/repo/auth_repo_impl.dart';
import '../api/api_service.dart';
import '../api/dio_factory.dart';

final getIt = GetIt.instance;

void setupGetIt() {
  // Dio + ApiServices
  final Dio dio = DioFactory.getDio();
  getIt.registerLazySingleton<ApiServices>(() => ApiServices(dio: dio));

  // Auth repository
  getIt.registerLazySingleton<AuthRepo>(
    () => AuthRepoImpl(apiServices: getIt<ApiServices>()),
  );
}
