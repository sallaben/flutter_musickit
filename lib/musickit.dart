import 'dart:async';

import 'package:flutter/services.dart';


class Musickit {
  static const MethodChannel _channel = const MethodChannel('musickit');

  static Future<String> get appleMusicRequestPermission async {
    return await _channel.invokeMethod('appleMusicRequestPermission');
  }

  static Future<String> get appleMusicCheckIfDeviceCanPlayback async {
    return await _channel.invokeMethod('appleMusicCheckIfDeviceCanPlayback');
  }

  static Future<String> fetchUserToken(String developerToken) async {
    return await _channel.invokeMethod('fetchUserToken', developerToken);
  }

  static Future<String> appleMusicPlayTrackId(List ids) async {
    return await _channel.invokeMethod('appleMusicPlayTrackId', ids);
  }
}
