import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/logic/chat_cubit/chat_cubit.dart';
import '../../../../core/utils/logic/chat_cubit/chat_state_extension.dart';
import '../../../../core/utils/model/dispatcher_chat_model.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../../../../core/utils/widgets/custom_toastification.dart';
import '../../../../core/utils/widgets/loading_dialog.dart';
import '../widgets/all_messages_section.dart';
import '../widgets/send_message_section.dart';

class ChatView extends StatelessWidget {
  const ChatView({this.isClient = false, super.key, this.dispatcherChatModel});
  final bool isClient;
  final DispatcherChatModel? dispatcherChatModel;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.lightWhite,
        foregroundColor: AppColors.white,
        title: isClient
            ? Text('خدمة العملاء', style: AppStyle.styleMedium18)
            : ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CustomAvatar(
                  imageUrl: dispatcherChatModel?.profilePicture,
                  whiteBackground: true,
                  radius: 20,
                ),
                title: Text(
                  dispatcherChatModel?.clientName ?? '',
                  style: AppStyle.styleMedium16.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
        titleSpacing: 0,
        actions: [
          if (!isClient)
            BlocListener<ChatCubit, ChatState>(
              listenWhen: (previous, current) => _listenWhen(current),
              listener: (context, state) {
                if (state.status.isCloseChatSuccess) {
                  context.pop();
                  successToast(context, 'عملية ناجحة', state.successMessage);
                  context.pop();
                } else if (state.status.isCloseChatFailure) {
                  context.pop();
                  errorToast(context, 'عملية فاشلة', state.errorMessage);
                } else if (state.status.isCloseChatLoading) {
                  loadingDialog(context);
                }
              },
              child: IconButton(
                onPressed: () {
                  context.read<ChatCubit>().closeChat();
                },
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCallDisabled02,
                  color: AppColors.white,
                ),
                style: IconButton.styleFrom(backgroundColor: Colors.red),
              ),
            ),
          horizontalSpace(6),
        ],
      ),
      body: BlocBuilder<ChatCubit, ChatState>(
        buildWhen: (previous, current) => _buildAndListenWhen(current),
        builder: (context, state) {
          if (state.status.isConnected) {
            return Column(
              children: [
                const Expanded(child: AllMessagesSection()),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SendMessageSection(),
                ),
                verticalSpace(6),
              ],
            );
          } else if (state.status.isError) {
            return CustomFailureWidget(text: state.errorMessage);
          }
          return const CustomLoadingWidget();
        },
      ),
    );
  }

  bool _listenWhen(ChatState state) {
    return state.status.isCloseChatSuccess ||
        state.status.isCloseChatFailure ||
        state.status.isCloseChatLoading;
  }

  bool _buildAndListenWhen(ChatState state) {
    return state.status.isConnected ||
        state.status.isError ||
        state.status.isConnecting;
  }
}
