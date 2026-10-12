import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/helpers/account_blocked.dart';
import 'core/helpers/navigation_handler.dart';
import 'core/routing/app_router.dart';
import 'core/theming/app_colors.dart';
import 'generated/l10n.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => AccountBlocked.check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back in the foreground: sign out now if the account was blocked meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AccountBlocked.check();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      // Larger reference than the 375×812 it was authored at, so flutter_screenutil
      // scales the whole UI down ~18% — the design read as oversized/"zoomed in".
      designSize: const Size(440, 952),
      minTextAdapt: true,
      builder: (context, child) {
        return _myMaterialApp();
      },
    );
  }

  MaterialApp _myMaterialApp() {
    return MaterialApp(
      theme: _appTheme(),
      builder: _mediaQueryWidget,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      navigatorKey: NavigationHandler.navigatorKey,
      initialRoute: AppRouter.initialRoute(),
      onGenerateRoute: AppRouter.generateRoute,
    );
  }

  MediaQuery _mediaQueryWidget(BuildContext context, Widget? child) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: child!,
    );
  }

  ThemeData _appTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.black,
      primaryColor: AppColors.primary,
      appBarTheme: const AppBarTheme(
        foregroundColor: AppColors.black,
        backgroundColor: AppColors.primary,
        toolbarHeight: 65,
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder()},
      ),
    );
  }
}
