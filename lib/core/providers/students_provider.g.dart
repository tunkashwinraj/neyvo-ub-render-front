// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'students_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$studentsNotifierHash() => r'0429a1a65af2cf883cb00772466159c77cb74e93';

/// See also [StudentsNotifier].
@ProviderFor(StudentsNotifier)
final studentsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      StudentsNotifier,
      List<StudentRecord>
    >.internal(
      StudentsNotifier.new,
      name: r'studentsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$studentsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$StudentsNotifier = AutoDisposeAsyncNotifier<List<StudentRecord>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
