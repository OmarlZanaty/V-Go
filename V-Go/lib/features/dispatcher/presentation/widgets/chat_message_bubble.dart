import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:intl/intl.dart';

import '../../../../core/helpers/spacing.dart';
import '../../../../core/theming/app_colors.dart';
import '../../../../core/theming/app_style.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/model/chat_message_model.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({required this.message, super.key});
  final ChatMessageModel message;

  bool isSender() {
    return message.senderId == AppConstants.kUserId;
  }

  String convertTime() {
    final DateTime sendAtDateTime = DateTime.parse(message.sendAt);

    final String hourAndMinute = DateFormat(
      'hh:mm',
      'en_US',
    ).format(sendAtDateTime);
    final String type = DateFormat('a').format(sendAtDateTime);
    return '$hourAndMinute $type';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: ChatBubble(
        backGroundColor: isSender() ? AppColors.primary : AppColors.darkGrey,
        clipper: ChatBubbleClipper5(
          type: isSender() ? BubbleType.sendBubble : BubbleType.receiverBubble,
          radius: 12,
        ),
        alignment: isSender() ? Alignment.centerRight : Alignment.centerLeft,
        elevation: 0,
        padding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 4),
        child: IntrinsicWidth(
          stepWidth: 10,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Wrap(
              runSpacing: 2,
              clipBehavior: Clip.hardEdge,
              crossAxisAlignment: WrapCrossAlignment.end,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.content,
                    style: AppStyle.styleMedium16.copyWith(
                      color: isSender() ? AppColors.black : AppColors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),

                horizontalSpace(6),
                Text(
                  convertTime(),
                  style: AppStyle.styleMedium10.copyWith(
                    color: isSender() ? AppColors.black : AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
