import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../ui/screens/calls/calls_section.dart';

part 'calls_ui_provider.g.dart';

@riverpod
class CallsUi extends _$CallsUi {
  @override
  CallsSection build() => CallsSection.calls;

  void select(CallsSection section) => state = section;
}
