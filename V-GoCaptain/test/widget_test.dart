// Basic smoke test for the V-Go Captain app.

import 'package:flutter_test/flutter_test.dart';
import 'package:v_go_captain/core/utils/app_constants.dart';

void main() {
  test('Captain app is restricted to the Driver role', () {
    expect(AppConstants.driverRole, 'Driver');
  });
}
