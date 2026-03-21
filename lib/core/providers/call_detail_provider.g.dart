// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$callDetailUiCtrlHash() => r'd3194c0b5722e2339386276b41b59f6edff0fed8';

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

abstract class _$CallDetailUiCtrl
    extends BuildlessAutoDisposeNotifier<CallDetailUiState> {
  late final String key;

  CallDetailUiState build(String key);
}

/// See also [CallDetailUiCtrl].
@ProviderFor(CallDetailUiCtrl)
const callDetailUiCtrlProvider = CallDetailUiCtrlFamily();

/// See also [CallDetailUiCtrl].
class CallDetailUiCtrlFamily extends Family<CallDetailUiState> {
  /// See also [CallDetailUiCtrl].
  const CallDetailUiCtrlFamily();

  /// See also [CallDetailUiCtrl].
  CallDetailUiCtrlProvider call(String key) {
    return CallDetailUiCtrlProvider(key);
  }

  @override
  CallDetailUiCtrlProvider getProviderOverride(
    covariant CallDetailUiCtrlProvider provider,
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
  String? get name => r'callDetailUiCtrlProvider';
}

/// See also [CallDetailUiCtrl].
class CallDetailUiCtrlProvider
    extends
        AutoDisposeNotifierProviderImpl<CallDetailUiCtrl, CallDetailUiState> {
  /// See also [CallDetailUiCtrl].
  CallDetailUiCtrlProvider(String key)
    : this._internal(
        () => CallDetailUiCtrl()..key = key,
        from: callDetailUiCtrlProvider,
        name: r'callDetailUiCtrlProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$callDetailUiCtrlHash,
        dependencies: CallDetailUiCtrlFamily._dependencies,
        allTransitiveDependencies:
            CallDetailUiCtrlFamily._allTransitiveDependencies,
        key: key,
      );

  CallDetailUiCtrlProvider._internal(
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
  CallDetailUiState runNotifierBuild(covariant CallDetailUiCtrl notifier) {
    return notifier.build(key);
  }

  @override
  Override overrideWith(CallDetailUiCtrl Function() create) {
    return ProviderOverride(
      origin: this,
      override: CallDetailUiCtrlProvider._internal(
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
  AutoDisposeNotifierProviderElement<CallDetailUiCtrl, CallDetailUiState>
  createElement() {
    return _CallDetailUiCtrlProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CallDetailUiCtrlProvider && other.key == key;
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
mixin CallDetailUiCtrlRef on AutoDisposeNotifierProviderRef<CallDetailUiState> {
  /// The parameter `key` of this provider.
  String get key;
}

class _CallDetailUiCtrlProviderElement
    extends
        AutoDisposeNotifierProviderElement<CallDetailUiCtrl, CallDetailUiState>
    with CallDetailUiCtrlRef {
  _CallDetailUiCtrlProviderElement(super.provider);

  @override
  String get key => (origin as CallDetailUiCtrlProvider).key;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
