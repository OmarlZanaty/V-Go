import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';

import 'core/helpers/navigation_handler.dart';
import 'core/routing/app_router.dart';
import 'core/theming/app_colors.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) => _materialApp(),
    );
  }

  Widget _materialApp() {
    return ToastificationWrapper(
      child: MaterialApp(
        theme: _theme(),
        builder: _mediaQuery,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        navigatorKey: NavigationHandler.navigatorKey,
        initialRoute: AppRouter.initialRoute(),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }

  Widget _mediaQuery(BuildContext context, Widget? child) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.0)),
        child: child!,
      ),
    );
  }

  ThemeData _theme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.black,
      primaryColor: AppColors.primary,
      appBarTheme: const AppBarTheme(
        foregroundColor: AppColors.black,
        backgroundColor: AppColors.primary,
        toolbarHeight: 65,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder()},
      ),
    );
  }
}
