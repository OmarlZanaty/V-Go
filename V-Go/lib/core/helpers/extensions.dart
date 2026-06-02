import 'package:flutter/material.dart';

import '../utils/app_constants.dart';

extension NavigationExtension on BuildContext {
  Future<dynamic> pushNamed(String routeName, {Object? arguments}) {
    return Navigator.pushNamed(this, routeName, arguments: arguments);
  }

  Future<dynamic> pushReplacementNamed(String routeName, {Object? arguments}) {
    return Navigator.pushReplacementNamed(
      this,
      routeName,
      arguments: arguments,
    );
  }

  Future<dynamic> pushNamedAndRemoveUntil(
    String routeName, {
    required RoutePredicate predicate,
    Object? arguments,
  }) {
    return Navigator.pushNamedAndRemoveUntil(
      this,
      routeName,
      predicate,
      arguments: arguments,
    );
  }

  void pop({bool? result}) => Navigator.pop(this, result);
}

extension StringExtension on String? {
  bool isNullOrEmpty() => this == null || this == "";
}

extension ListExtension<T> on List<T>? {
  bool isNullOrEmpty() => this == null || this!.isEmpty;
}

extension UserRoleExtension on UserRole {
  String get capitalized =>
      name[0].toUpperCase() + name.substring(1).toLowerCase();
}

extension ScooterTypeExtension on ScooterType {
  String get capitalized =>
      name[0].toUpperCase() + name.substring(1).toLowerCase();
}