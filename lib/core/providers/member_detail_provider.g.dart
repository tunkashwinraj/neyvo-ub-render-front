// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$memberDetailCtrlHash() => r'2d46cfaa1d2fc913de0bb09f0b8da1c54272bfc0';

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

abstract class _$MemberDetailCtrl
    extends BuildlessAutoDisposeNotifier<MemberDetailUiState> {
  late final String key;

  MemberDetailUiState build(String key);
}

/// See also [MemberDetailCtrl].
@ProviderFor(MemberDetailCtrl)
const memberDetailCtrlProvider = MemberDetailCtrlFamily();

/// See also [MemberDetailCtrl].
class MemberDetailCtrlFamily extends Family<MemberDetailUiState> {
  /// See also [MemberDetailCtrl].
  const MemberDetailCtrlFamily();

  /// See also [MemberDetailCtrl].
  MemberDetailCtrlProvider call(String key) {
    return MemberDetailCtrlProvider(key);
  }

  @override
  MemberDetailCtrlProvider getProviderOverride(
    covariant MemberDetailCtrlProvider provider,
  ) {
    return call(provider.key);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'memberDetailCtrlProvider';
}

/// See also [MemberDetailCtrl].
class MemberDetailCtrlProvider
    extends
        AutoDisposeNotifierProviderImpl<MemberDetailCtrl, MemberDetailUiState> {
  /// See also [MemberDetailCtrl].
  MemberDetailCtrlProvider(String key)
    : this._internal(
        () => MemberDetailCtrl()..key = key,
        from: memberDetailCtrlProvider,
        name: r'memberDetailCtrlProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$memberDetailCtrlHash,
        dependencies: MemberDetailCtrlFamily._dependencies,
        allTransitiveDependencies:
            MemberDetailCtrlFamily._allTransitiveDependencies,
        key: key,
      );

  MemberDetailCtrlProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.key,
  }) : super.internal();

  final String key;

  @override
  MemberDetailUiState runNotifierBuild(covariant MemberDetailCtrl notifier) {
    return notifier.build(key);
  }

  @override
  Override overrideWith(MemberDetailCtrl Function() create) {
    return ProviderOverride(
      origin: this,
      override: MemberDetailCtrlProvider._internal(
        () => create()..key = key,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        key: key,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<MemberDetailCtrl, MemberDetailUiState>
  createElement() {
    return _MemberDetailCtrlProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MemberDetailCtrlProvider && other.key == key;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, key.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MemberDetailCtrlRef
    on AutoDisposeNotifierProviderRef<MemberDetailUiState> {
  /// The parameter `key` of this provider.
  String get key;
}

class _MemberDetailCtrlProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          MemberDetailCtrl,
          MemberDetailUiState
        >
    with MemberDetailCtrlRef {
  _MemberDetailCtrlProviderElement(super.provider);

  @override
  String get key => (origin as MemberDetailCtrlProvider).key;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
