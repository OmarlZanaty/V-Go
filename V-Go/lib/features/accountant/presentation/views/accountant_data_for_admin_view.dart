import 'package:flutter/material.dart';

import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../widgets/accountant_dashboard_body.dart';

class AccountantDataForAdminView extends StatelessWidget {
  const AccountantDataForAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'المحاسبة'),
      body: const AccountantDashboardBody(),
    );
  }
}
