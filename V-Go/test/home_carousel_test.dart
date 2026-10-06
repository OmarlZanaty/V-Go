import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scooter_app/core/api/api_service.dart';
import 'package:scooter_app/core/di/di.dart';
import 'package:scooter_app/features/client/data/model/home_banner_model.dart';
import 'package:scooter_app/features/client/data/repo/home_banner_repo.dart';
import 'package:scooter_app/features/client/presentation/views/client_dashboard_view.dart';

class _FakeRepo extends HomeBannerRepo {
  _FakeRepo(this.server) : super(apiServices: ApiServices(dio: Dio()));
  List<HomeBannerModel> server;
  final clicks = <int>[];

  @override
  List<HomeBannerModel>? cached() => null;
  @override
  Future<List<HomeBannerModel>> fetch() async => server;
  @override
  Future<void> recordClick(int id) async => clicks.add(id);
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(440, 952),
    builder: (_, _) => const MaterialApp(home: Scaffold(body: CaroselView())),
  ));
  await tester.pump();
}

int _dots(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .where((c) => c.margin == const EdgeInsets.symmetric(horizontal: 3))
    .length;

void main() {
  tearDown(() => getIt.reset());

  testWidgets('no banners on the server -> the 4 bundled images', (tester) async {
    getIt.registerSingleton<HomeBannerRepo>(_FakeRepo([]));
    await _pump(tester);
    expect(find.byType(Image), findsWidgets);
    expect(_dots(tester), 4);
  });

  testWidgets('dashboard banners replace the defaults, count follows the server', (tester) async {
    getIt.registerSingleton<HomeBannerRepo>(_FakeRepo(const [
      HomeBannerModel(id: 1, imageUrl: 'https://example.com/a.jpg', linkUrl: 'https://example.com'),
      HomeBannerModel(id: 2, imageUrl: 'https://example.com/b.jpg'),
    ]));
    await _pump(tester);
    expect(_dots(tester), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single banner shows without auto-scroll errors', (tester) async {
    getIt.registerSingleton<HomeBannerRepo>(_FakeRepo(const [
      HomeBannerModel(id: 7, imageUrl: 'https://example.com/only.jpg'),
    ]));
    await _pump(tester);
    await tester.pump(const Duration(seconds: 9));
    expect(_dots(tester), 1);
    expect(tester.takeException(), isNull);
  });
}
