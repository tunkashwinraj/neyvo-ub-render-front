// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$studentDetailCtrlHash() => r'b866a44fdd4c3080d35170c18409cc06517e6e3f';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$StudentDetailCtrl
    extends BuildlessAutoDisposeNotifier<StudentDetailUiState> {
  late final String studentId;

  StudentDetailUiState build(String studentId);
}

/// See also [StudentDetailCtrl].
@ProviderFor(StudentDetailCtrl)
const studentDetailCtrlProvider = StudentDetailCtrlFamily();

/// See also [StudentDetailCtrl].
class StudentDetailCtrlFamily extends Family<StudentDetailUiState> {
  /// See also [StudentDetailCtrl].
  const StudentDetailCtrlFamily();

  /// See also [StudentDetailCtrl].
  StudentDetailCtrlProvider call(String studentId) {
    return StudentDetailCtrlProvider(studentId);
  }

  @override
  StudentDetailCtrlProvider getProviderOverride(
    covariant StudentDetailCtrlProvider provider,
  ) {
    return call(provider.studentId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'studentDetailCtrlProvider';
}

/// See also [StudentDetailCtrl].
class StudentDetailCtrlProvider
    extends
        AutoDisposeNotifierProviderImpl<
          StudentDetailCtrl,
          StudentDetailUiState
        > {
  /// See also [StudentDetailCtrl].
  StudentDetailCtrlProvider(String studentId)
    : this._internal(
        () => StudentDetailCtrl()..studentId = studentId,
        from: studentDetailCtrlProvider,
        name: r'studentDetailCtrlProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$studentDetailCtrlHash,
        dependencies: StudentDetailCtrlFamily._dependencies,
        allTransitiveDependencies:
            StudentDetailCtrlFamily._allTransitiveDependencies,
        studentId: studentId,
      );

  StudentDetailCtrlProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.studentId,
  }) : super.internal();

  final String studentId;

  @override
  StudentDetailUiState runNotifierBuild(covariant StudentDetailCtrl notifier) {
    return notifier.build(studentId);
  }

  @override
  Override overrideWith(StudentDetailCtrl Function() create) {
    return ProviderOverride(
      origin: this,
      override: StudentDetailCtrlProvider._internal(
        () => create()..studentId = studentId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        studentId: studentId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<StudentDetailCtrl, StudentDetailUiState>
  createElement() {
    return _StudentDetailCtrlProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StudentDetailCtrlProvider && other.studentId == studentId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, studentId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin StudentDetailCtrlRef
    on AutoDisposeNotifierProviderRef<StudentDetailUiState> {
  /// The parameter `studentId` of this provider.
  String get studentId;
}

class _StudentDetailCtrlProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          StudentDetailCtrl,
          StudentDetailUiState
        >
    with StudentDetailCtrlRef {
  _StudentDetailCtrlProviderElement(super.provider);

  @override
  String get studentId => (origin as StudentDetailCtrlProvider).studentId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
