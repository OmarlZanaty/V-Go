import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import '../../../trips/presentation/logic/trip_cubit/trip_cubit.dart';
import 'change_kilo_metre_price_dialog.dart';
import 'dashboard_interactive_container.dart';

class ChangeKiloPriceSection extends StatelessWidget {
  const ChangeKiloPriceSection({required this.currentPrice, super.key});
  final String currentPrice;
  @override
  Widget build(BuildContext context) {
    return BlocListener<TripCubit, TripState>(
      listenWhen: (previous, current) => _listenWhen(current),
      listener: (context, state) {
        if (state.status.isChangeKiloPriceSuccess) {
          context.pop();
          successToast(context, 'عملية ناجحة', state.successMessage);
        } else if (state.status.isChangeKiloPriceFailure) {
          context.pop();
          errorToast(context, 'عملية فاشلة', state.errorMessage);
        } else if (state.status.isChangeKiloPriceLoading) {
          loadingDialog(context);
        }
      },
      child: DashboardInteractiveContainer(
        title: 'سعر الكيلو',
        icon: HugeIcons.strokeRoundedEdit03,
        onTap: () {
          changeKiloMetrePriceDialog(
            context: context,
            currentPrice: currentPrice,
          );
        },
      ),
    );
  }

  bool _listenWhen(TripState state) {
    return state.status.isChangeKiloPriceSuccess ||
        state.status.isChangeKiloPriceFailure ||
        state.status.isChangeKiloPriceLoading;
  }
}
