// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'studio_project_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$studioProjectDetailHash() =>
    r'97ae71cef0b1ca314615e63c95ab8f716a1f0c04';

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

abstract class _$StudioProjectDetail
    extends BuildlessAutoDisposeAsyncNotifier<Map<String, dynamic>> {
  late final String projectId;

  FutureOr<Map<String, dynamic>> build(String projectId);
}

/// See also [StudioProjectDetail].
@ProviderFor(StudioProjectDetail)
const studioProjectDetailProvider = StudioProjectDetailFamily();

/// See also [StudioProjectDetail].
class StudioProjectDetailFamily
    extends Family<AsyncValue<Map<String, dynamic>>> {
  /// See also [StudioProjectDetail].
  const StudioProjectDetailFamily();

  /// See also [StudioProjectDetail].
  StudioProjectDetailProvider call(String projectId) {
    return StudioProjectDetailProvider(projectId);
  }

  @override
  StudioProjectDetailProvider getProviderOverride(
    covariant StudioProjectDetailProvider provider,
  ) {
    return call(provider.projectId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'studioProjectDetailProvider';
}

/// See also [StudioProjectDetail].
class StudioProjectDetailProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          StudioProjectDetail,
          Map<String, dynamic>
        > {
  /// See also [StudioProjectDetail].
  StudioProjectDetailProvider(String projectId)
    : this._internal(
        () => StudioProjectDetail()..projectId = projectId,
        from: studioProjectDetailProvider,
        name: r'studioProjectDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$studioProjectDetailHash,
        dependencies: StudioProjectDetailFamily._dependencies,
        allTransitiveDependencies:
            StudioProjectDetailFamily._allTransitiveDependencies,
        projectId: projectId,
      );

  StudioProjectDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.projectId,
  }) : super.internal();

  final String projectId;

  @override
  FutureOr<Map<String, dynamic>> runNotifierBuild(
    covariant StudioProjectDetail notifier,
  ) {
    return notifier.build(projectId);
  }

  @override
  Override overrideWith(StudioProjectDetail Function() create) {
    return ProviderOverride(
      origin: this,
      override: StudioProjectDetailProvider._internal(
        () => create()..projectId = projectId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        projectId: projectId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    StudioProjectDetail,
    Map<String, dynamic>
  >
  createElement() {
    return _StudioProjectDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StudioProjectDetailProvider && other.projectId == projectId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, projectId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin StudioProjectDetailRef
    on AutoDisposeAsyncNotifierProviderRef<Map<String, dynamic>> {
  /// The parameter `projectId` of this provider.
  String get projectId;
}

class _StudioProjectDetailProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          StudioProjectDetail,
          Map<String, dynamic>
        >
    with StudioProjectDetailRef {
  _StudioProjectDetailProviderElement(super.provider);

  @override
  String get projectId => (origin as StudioProjectDetailProvider).projectId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
