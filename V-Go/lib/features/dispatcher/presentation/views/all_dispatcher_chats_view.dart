import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logic/chat_cubit/chat_cubit.dart';
import '../../../../core/utils/logic/chat_cubit/chat_state_extension.dart';
import '../../../../core/utils/widgets/custom_app_bar.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import '../widgets/dispatcher_chat_item.dart';

class AllDispatcherChatsView extends StatelessWidget {
  const AllDispatcherChatsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(title: 'جميع المحادثات'),
      body: BlocBuilder<ChatCubit, ChatState>(
        builder: (context, state) {
          if (state.status.isGetDispatcherChatsSuccess) {
            final allChats = [...state.dispatcherChats];
            if (allChats.isEmpty) {
              return const CustomFailureWidget(text: 'لا توجد محادثات');
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: allChats.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: DispatcherChatItem(
                    dispatcherChatModel: allChats[index],
                  ),
                );
              },
            );
          } else if (state.status.isGetDispatcherChatsFailure) {
            return CustomFailureWidget(text: state.errorMessage);
          }
          return const CustomLoadingWidget();
        },
      ),
    );
  }
}
