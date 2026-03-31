import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'students_hub_tab_provider.g.dart';

@riverpod
class StudentsHubTab extends _$StudentsHubTab {
  @override
  int build() => 0;

  void select(int index) => state = index;
}
