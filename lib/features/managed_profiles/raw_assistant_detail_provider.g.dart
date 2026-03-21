// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'raw_assistant_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$rawAssistantDetailCtrlHash() =>
    r'4cccffb17421cb6055024f48c04bd78c4817d502';

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

abstract class _$RawAssistantDetailCtrl
    extends BuildlessAutoDisposeNotifier<RawAssistantDetailUiState> {
  late final String profileId;

  RawAssistantDetailUiState build(String profileId);
}

/// See also [RawAssistantDetailCtrl].
@ProviderFor(RawAssistantDetailCtrl)
const rawAssistantDetailCtrlProvider = RawAssistantDetailCtrlFamily();

/// See also [RawAssistantDetailCtrl].
class RawAssistantDetailCtrlFamily extends Family<RawAssistantDetailUiState> {
  /// See also [RawAssistantDetailCtrl].
  const RawAssistantDetailCtrlFamily();

  /// See also [RawAssistantDetailCtrl].
  RawAssistantDetailCtrlProvider call(String profileId) {
    return RawAssistantDetailCtrlProvider(profileId);
  }

  @override
  RawAssistantDetailCtrlProvider getProviderOverride(
    covariant RawAssistantDetailCtrlProvider provider,
  ) {
    return call(provider.profileId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'rawAssistantDetailCtrlProvider';
}

/// See also [RawAssistantDetailCtrl].
class RawAssistantDetailCtrlProvider
    extends
        AutoDisposeNotifierProviderImpl<
          RawAssistantDetailCtrl,
          RawAssistantDetailUiState
        > {
  /// See also [RawAssistantDetailCtrl].
  RawAssistantDetailCtrlProvider(String profileId)
    : this._internal(
        () => RawAssistantDetailCtrl()..profileId = profileId,
        from: rawAssistantDetailCtrlProvider,
        name: r'rawAssistantDetailCtrlProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$rawAssistantDetailCtrlHash,
        dependencies: RawAssistantDetailCtrlFamily._dependencies,
        allTransitiveDependencies:
            RawAssistantDetailCtrlFamily._allTransitiveDependencies,
        profileId: profileId,
      );

  RawAssistantDetailCtrlProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.profileId,
  }) : super.internal();

  final String profileId;

  @override
  RawAssistantDetailUiState runNotifierBuild(
    covariant RawAssistantDetailCtrl notifier,
  ) {
    return notifier.build(profileId);
  }

  @override
  Override overrideWith(RawAssistantDetailCtrl Function() create) {
    return ProviderOverride(
      origin: this,
      override: RawAssistantDetailCtrlProvider._internal(
        () => create()..profileId = profileId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        profileId: profileId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    RawAssistantDetailCtrl,
    RawAssistantDetailUiState
  >
  createElement() {
    return _RawAssistantDetailCtrlProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RawAssistantDetailCtrlProvider &&
        other.profileId == profileId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, profileId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RawAssistantDetailCtrlRef
    on AutoDisposeNotifierProviderRef<RawAssistantDetailUiState> {
  /// The parameter `profileId` of this provider.
  String get profileId;
}

class _RawAssistantDetailCtrlProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          RawAssistantDetailCtrl,
          RawAssistantDetailUiState
        >
    with RawAssistantDetailCtrlRef {
  _RawAssistantDetailCtrlProviderElement(super.provider);

  @override
  String get profileId => (origin as RawAssistantDetailCtrlProvider).profileId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
