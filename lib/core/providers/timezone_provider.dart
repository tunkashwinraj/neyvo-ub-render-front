import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/user_timezone_service.dart';

/// IANA timezone from Settings ([UserTimezoneService]); update after settings load/save via [UserTimezoneNotifier.syncFromService].
class UserTimezoneNotifier extends Notifier<String> {
  @override
  String build() => UserTimezoneService.currentTimezone;

  void syncFromService() {
    state = UserTimezoneService.currentTimezone;
  }
}

final userTimezoneProvider = NotifierProvider<UserTimezoneNotifier, String>(UserTimezoneNotifier.new);
