import 'dart:developer';

import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';
import '../utils/app_constants.dart';
import '../utils/model/send_rating_model.dart';

class RatingService {
  late final HubConnection _hubConnection;
  bool _isConnected = false;

  RatingService() {
    _initializeHubConnection();
  }

  void _initializeHubConnection() {
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          AppConfig.hubUrl('ratingHub'),
          options: HttpConnectionOptions(
            requestTimeout: 60000,
            accessTokenFactory: () async => AppConstants.kToken,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _hubConnection.onclose(({error}) {
      _isConnected = false;
      log(
        'RatingHub connection closed: ${error?.toString()}',
        name: 'RatingService',
      );
    });
  }

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      await _hubConnection.start();
      _isConnected = true;
      log('Connected to RatingHub', name: 'RatingService');
    } catch (e) {
      log('Error connecting to RatingHub: $e', name: 'RatingService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }
  }

  Future<void> sendRating(SendRatingModel ratingModel) async {
    if (!_isConnected) {
      log(
        'Cannot send rating: Not connected to RatingHub',
        name: 'RatingService',
      );
      throw 'حدث خطاء اثناء الاتصال وارسال التقييم , حاول مره اخرى';
    }

    try {
      await _hubConnection.invoke('SendRating', args: [ratingModel.toJson()]);
      log('Rating sent: ${ratingModel.toJson()}', name: 'RatingService');
    } catch (e) {
      log('Error sending rating: $e', name: 'RatingService');
      throw 'حدث خطاء اثناء ارسال التقييم , حاول مره اخرى';
    }
  }

  Future<void> disconnect() async {
    if (!_isConnected) return;
    try {
      await _hubConnection.stop();
      _isConnected = false;
      log('Disconnected from RatingHub', name: 'RatingService');
    } catch (e) {
      log('Error disconnecting from RatingHub: $e', name: 'RatingService');
      rethrow;
    }
  }

  void dispose() => disconnect();
}
