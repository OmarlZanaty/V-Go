import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logic/chat_cubit/chat_cubit.dart';
import '../../../../core/utils/logic/chat_cubit/chat_state_extension.dart';
import '../../../../core/utils/widgets/custom_failure_widget.dart';
import '../../../../core/utils/widgets/custom_loading_widget.dart';
import 'chat_message_bubble.dart';

class AllMessagesSection extends StatefulWidget {
  const AllMessagesSection({super.key});

  @override
  State<AllMessagesSection> createState() => _AllMessagesSectionState();
}

class _AllMessagesSectionState extends State<AllMessagesSection> {
  final ScrollController _scrollController = ScrollController();
  bool _isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    context.read<ChatCubit>().getAllMessages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isFetchingMore) {
      final state = context.read<ChatCubit>().state;
      if (state.hasMoreMessages && !state.status.isGetAllMessagesLoading) {
        setState(() => _isFetchingMore = true);
        log('Triggering loadMoreMessages');
        context
            .read<ChatCubit>()
            .loadMoreMessages(take: 30)
            .then((_) {
              setState(() => _isFetchingMore = false);
            })
            .catchError((e) {
              setState(() => _isFetchingMore = false);
              log('Error loading more messages: $e');
            });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      buildWhen: _buildWhen,
      builder: (context, state) {
        if (state.status.isGetAllMessagesSuccess ||
            (state.status.isGetAllMessagesLoading &&
                state.messages.isNotEmpty)) {
          return ListView.builder(
            controller: _scrollController,
            reverse: true,
            itemCount: state.messages.length + (_isFetchingMore ? 1 : 0),
            itemBuilder: (BuildContext context, int index) {
              if (index == state.messages.length && _isFetchingMore) {
                return const CustomLoadingWidget();
              }
              return ChatMessageBubble(message: state.messages[index]);
            },
          );
        } else if (state.status.isGetAllMessagesFailure) {
          return CustomFailureWidget(text: state.errorMessage);
        }
        return const CustomLoadingWidget();
      },
    );
  }

  bool _buildWhen(ChatState previous, ChatState current) {
    return current.status.isGetAllMessagesSuccess ||
        current.status.isGetAllMessagesFailure ||
        current.status.isGetAllMessagesLoading ||
        previous.messages.length != current.messages.length ||
        previous.hasMoreMessages != current.hasMoreMessages;
  }
}
