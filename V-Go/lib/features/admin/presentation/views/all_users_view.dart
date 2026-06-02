import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/logic/user_cubit/user_cubit.dart';
import '../../../../core/utils/logic/user_cubit/user_state_extension.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_refresh_indicator.dart';
import '../widgets/custom_search_field.dart';
import '../widgets/user_list_tile_item.dart';

class AllUsersView extends StatefulWidget {
  const AllUsersView({
    required this.role,
    super.key,
    this.fromAccountantDashboard = false,
  });
  final UserRole role;
  final bool fromAccountantDashboard;
  @override
  State<AllUsersView> createState() => _AllUsersViewState();
}

class _AllUsersViewState extends State<AllUsersView> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isSearching = _searchFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  String getRole(UserRole role) {
    switch (role) {
      case UserRole.accountant:
        return 'جميع المحاسبين';
      case UserRole.client:
        return 'جميع العملاء';
      case UserRole.driver:
        return 'جميع السائقين';
      case UserRole.dispatcher:
        return 'جميع الموزعين';
      case UserRole.admin:
        return 'جميع المناديب';
    }
  }

  bool isSearching(UserState state) {
    return (_isSearching && _searchController.text.isNotEmpty) ||
        (state.searchedUsers.isNotEmpty && _searchController.text.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: getRole(widget.role)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: CustomSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
            ),
          ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'يتم البحث...',
                  style: AppStyle.styleMedium14.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          Expanded(
            child: BlocBuilder<UserCubit, UserState>(
              buildWhen: (previous, current) => _buildWhen(current),
              builder: (context, state) {
                if (state.status.isGetAllUsersSuccess) {
                  return CustomRefreshIndicator(
                    onRefresh: () async => context
                        .read<UserCubit>()
                        .getAllUsers(role: widget.role),
                    child: ListView.builder(
                      itemCount: isSearching(state)
                          ? state.searchedUsers.length
                          : state.users.length,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 16,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: UserListTileItem(
                            user: isSearching(state)
                                ? state.searchedUsers[index]
                                : state.users[index],
                            onTap: () {
                              _isSearching = false;
                              _searchController.text = '';
                              _searchFocusNode.unfocus();
                              FocusManager.instance.primaryFocus?.unfocus();
                              context.pushNamed(
                               Routes.userDetailsViewRoute,
                                arguments: {
                                  'userId': state.users[index].id,
                                  'isDriver': widget.role == UserRole.driver,
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  );
                } else if (state.status.isGetAllUsersFailure) {
                  return CustomFailureWidget(text: state.errorMessage);
                }
                return const CustomLoadingWidget();
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _buildWhen(UserState state) {
    return state.status.isGetAllUsersSuccess ||
        state.status.isGetAllUsersFailure ||
        state.status.isGetAllUsersLoading;
  }
}
