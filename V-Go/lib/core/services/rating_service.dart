import 'dart:developer';

import 'package:signalr_netcore/signalr_client.dart';

import '../api/dio_factory.dart';
import '../config/app_config.dart';
import '../utils/app_constants.dart';
import '../utils/model/send_rating_model.dart';

class RatingService {
  late final HubConnection _hubConnection;

  RatingService() {
    _initializeHubConnection();
  }

  void _initializeHubConnection() {
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          AppConfig.hubUrl('ratingHub'),
          options: HttpConnectionOptions(
            requestTimeout: 60000,
            // Read the stored token each time so a refreshed JWT is used.
            accessTokenFactory: () async {
              final token = await TokenService().getAccessToken();
              return token.isNotEmpty ? token : AppConstants.kToken;
            },
          ),
        )
        .withAutomaticReconnect()
        .build();

    _hubConnection.onclose(({error}) {
      log(
        'RatingHub connection closed: ${error?.toString()}',
        name: 'RatingService',
      );
    });
  }

  Future<void> connect() async {
    try {
      await _ensureConnected();
      log('Connected to RatingHub', name: 'RatingService');
    } catch (e) {
      log('Error connecting to RatingHub: $e', name: 'RatingService');
      throw 'حدث خطاء اثناء الاتصال , حاول مره اخرى';
    }
  }

  /// The rating screen is shown at the end of a (possibly long) trip, by which
  /// time the socket may have dropped or the JWT expired. Reconnect on demand
  /// instead of failing the rating.
  Future<void> _ensureConnected() async {
    const step = Duration(milliseconds: 300);
    var refreshed = false;
    for (var waited = Duration.zero;
        waited < const Duration(seconds: 8);
        waited += step) {
      final state = _hubConnection.state;
      if (state == HubConnectionState.Connected) return;
      if (state == HubConnectionState.Disconnected) {
        try {
          await _hubConnection.start();
          return;
        } catch (e) {
          log('RatingHub start failed: $e', name: 'RatingService');
          // Most likely an expired token (401 on negotiate) — refresh once.
          if (!refreshed) {
            refreshed = true;
            try {
              await TokenService().refreshToken();
            } catch (_) {}
          }
        }
      }
      await Future.delayed(step);
    }
    if (_hubConnection.state != HubConnectionState.Connected) {
      throw StateError('RatingHub not connected');
    }
  }

  Future<void> sendRating(SendRatingModel ratingModel) async {
    try {
      await _ensureConnected();
    } catch (e) {
      log('Cannot send rating: $e', name: 'RatingService');
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
    if (_hubConnection.state == HubConnectionState.Disconnected) return;
    try {
      await _hubConnection.stop();
      log('Disconnected from RatingHub', name: 'RatingService');
    } catch (e) {
      log('Error disconnecting from RatingHub: $e', name: 'RatingService');
    }
  }

  void dispose() => disconnect();
}
