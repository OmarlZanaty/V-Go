import 'package:flutter/material.dart';

import '../../../../core/helpers/extensions.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/model/dispatcher_chat_model.dart';
import '../../../../core/utils/widgets/custom_avatar.dart';

class DispatcherChatItem extends StatelessWidget {
  const DispatcherChatItem({required this.dispatcherChatModel, super.key});
  final DispatcherChatModel dispatcherChatModel;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        context.pushNamed(
          Routes.chatViewRoute,
          arguments: {
            'isClient': false,
            'dispatcherChatModel': dispatcherChatModel,
          },
        );
      },
      //contentPadding: EdgeInsets.zero,
      leading: CustomAvatar(
        imageUrl: dispatcherChatModel.profilePicture,
        radius: 24,
      ),
      title: Text(
        dispatcherChatModel.clientName,
        style: AppStyle.styleMedium16.copyWith(color: Colors.white),
      ),
    );
  }
}
