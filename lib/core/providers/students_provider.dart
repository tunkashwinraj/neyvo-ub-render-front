import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';
import 'api_provider.dart';

part 'students_provider.g.dart';

class StudentRecord {
  const StudentRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.raw,
  });

  final String id;
  final String name;
  final String phone;
  final Map<String, dynamic> raw;

  factory StudentRecord.fromJson(Map<String, dynamic> json) {
    return StudentRecord(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

@riverpod
class StudentsNotifier extends _$StudentsNotifier {
  @override
  Future<List<StudentRecord>> build() async {
    ref.watch(speariaApiProvider);
    final res = await NeyvoPulseApi.listStudents();
    final list = (res['students'] as List? ?? const [])
        .map((e) => StudentRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return list;
  }
}
