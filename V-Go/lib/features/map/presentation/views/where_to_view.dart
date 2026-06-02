import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/di.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../trips/data/model/trip_model.dart';
import '../../data/model/place_suggestion_model.dart';
import '../../data/repo/map_repo.dart';
import '../logic/map_bloc/map_bloc.dart';
import '../logic/map_bloc/map_event.dart';
import '../logic/map_bloc/map_state.dart';

class WhereToView extends StatefulWidget {
  const WhereToView({super.key, this.isFrom = false});
  final bool isFrom;

  @override
  State<WhereToView> createState() => _WhereToViewState();
}

class _WhereToViewState extends State<WhereToView> {
  final TextEditingController whereToController = TextEditingController();
  String? sessionToken;
  late Uuid uuid;

  @override
  void initState() {
    uuid = const Uuid();
    super.initState();
  }

  @override
  void dispose() {
    whereToController.dispose();
    super.dispose();
  }

  Future<void> _onSuggestionSelected(
    BuildContext context,
    PlaceSuggestionModel suggestion,
  ) async {
    try {
      final MapRepo mapRepo = getIt();
      final loc = await mapRepo.getPlaceLocation(suggestion.placeId);
      final latLng = LatLng(loc.latitude, loc.longitude);

      if (!context.mounted) return;

      Navigator.of(context).pop(
        TripLocationModel(
          lat: latLng.latitude,
          lng: latLng.longitude,
          address: suggestion.description,
        ),
      );
    } catch (e) {
      errorToast(context, 'حدث خطا', 'حدث خطا , حاول مرة اخري');
    }
  }

  Widget _buildPlaceSuggestions() {
    return BlocBuilder<MapBloc, MapState>(
      builder: (context, state) {
        if (state.placeSuggestions.isEmpty) return _buildHistory();
        return ListView.separated(
          separatorBuilder: (context, index) => const Divider(
            height: 4,
            color: AppColors.lightWhite,
            endIndent: 14,
            indent: 14,
          ),
          itemCount: state.placeSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = state.placeSuggestions[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),

              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.all(Radius.circular(50)),
              ),
              horizontalTitleGap: 10,
              leading: const Icon(
                Icons.add_location_sharp,
                color: AppColors.primary,
                size: 22,
              ),
              title: Text(
                suggestion.description,
                style: AppStyle.styleMedium14.copyWith(color: Colors.white),
              ),
              onTap: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                await HiveService.addSearch(suggestion);
                if (!context.mounted) return;
                _onSuggestionSelected(context, suggestion);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHistory() {
    final history = HiveService.getHistory();
    if (history.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      itemCount: history.length,
      separatorBuilder: (_, __) => const Divider(
        height: 4,
        color: AppColors.lightWhite,
        endIndent: 14,
        indent: 14,
      ),
      itemBuilder: (context, index) {
        final item = history[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.all(Radius.circular(50)),
          ),
          horizontalTitleGap: 10,
          leading: const Icon(Icons.history, color: Colors.white),
          title: Text(
            item.description,
            style: AppStyle.styleMedium14.copyWith(color: Colors.white),
          ),
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            whereToController.text = item.description;
            _onSuggestionSelected(context, item);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(
        title: widget.isFrom ? "موقع الانطلاق" : "وجهة الذهاب",
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              autofocus: true,
              onChanged: (e) {
                sessionToken ??= uuid.v4();
                context.read<MapBloc>().add(
                  SearchLocation(e, isFrom: false, sessionToken: sessionToken!),
                );
              },
              controller: whereToController,
              cursorColor: AppColors.primary,
              style: AppStyle.styleMedium14.copyWith(color: AppColors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.lightWhite,
                hintText: widget.isFrom
                    ? "اكتب موقع الانطلاق"
                    : "اكتب وجهة الذهاب",
                hintStyle: AppStyle.styleMedium14.copyWith(
                  color: Colors.grey[600],
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppColors.grey),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),

          // قائمة النتائج
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildPlaceSuggestions(),
            ),
          ),
        ],
      ),
    );
  }
}
