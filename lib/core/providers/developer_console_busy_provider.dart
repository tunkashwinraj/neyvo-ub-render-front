import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'developer_console_busy_provider.g.dart';

@riverpod
class DeveloperConsoleBusy extends _$DeveloperConsoleBusy {
  @override
  bool build() => false;

  void setBusy(bool value) {
    state = value;
  }
}
