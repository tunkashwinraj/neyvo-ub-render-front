// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messaging_defaults_test_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$messagingDefaultsTestCtrlHash() =>
    r'05f05f25344d6906b33286a31e1e1656a932d17b';

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

abstract class _$MessagingDefaultsTestCtrl
    extends BuildlessAutoDisposeNotifier<MessagingTestUiState> {
  late final String operatorId;

  MessagingTestUiState build(String operatorId);
}

/// See also [MessagingDefaultsTestCtrl].
@ProviderFor(MessagingDefaultsTestCtrl)
const messagingDefaultsTestCtrlProvider = MessagingDefaultsTestCtrlFamily();

/// See also [MessagingDefaultsTestCtrl].
class MessagingDefaultsTestCtrlFamily extends Family<MessagingTestUiState> {
  /// See also [MessagingDefaultsTestCtrl].
  const MessagingDefaultsTestCtrlFamily();

  /// See also [MessagingDefaultsTestCtrl].
  MessagingDefaultsTestCtrlProvider call(String operatorId) {
    return MessagingDefaultsTestCtrlProvider(operatorId);
  }

  @override
  MessagingDefaultsTestCtrlProvider getProviderOverride(
    covariant MessagingDefaultsTestCtrlProvider provider,
  ) {
    return call(provider.operatorId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'messagingDefaultsTestCtrlProvider';
}

/// See also [MessagingDefaultsTestCtrl].
class MessagingDefaultsTestCtrlProvider
    extends
        AutoDisposeNotifierProviderImpl<
          MessagingDefaultsTestCtrl,
          MessagingTestUiState
        > {
  /// See also [MessagingDefaultsTestCtrl].
  MessagingDefaultsTestCtrlProvider(String operatorId)
    : this._internal(
        () => MessagingDefaultsTestCtrl()..operatorId = operatorId,
        from: messagingDefaultsTestCtrlProvider,
        name: r'messagingDefaultsTestCtrlProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$messagingDefaultsTestCtrlHash,
        dependencies: MessagingDefaultsTestCtrlFamily._dependencies,
        allTransitiveDependencies:
            MessagingDefaultsTestCtrlFamily._allTransitiveDependencies,
        operatorId: operatorId,
      );

  MessagingDefaultsTestCtrlProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.operatorId,
  }) : super.internal();

  final String operatorId;

  @override
  MessagingTestUiState runNotifierBuild(
    covariant MessagingDefaultsTestCtrl notifier,
  ) {
    return notifier.build(operatorId);
  }

  @override
  Override overrideWith(MessagingDefaultsTestCtrl Function() create) {
    return ProviderOverride(
      origin: this,
      override: MessagingDefaultsTestCtrlProvider._internal(
        () => create()..operatorId = operatorId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        operatorId: operatorId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    MessagingDefaultsTestCtrl,
    MessagingTestUiState
  >
  createElement() {
    return _MessagingDefaultsTestCtrlProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MessagingDefaultsTestCtrlProvider &&
        other.operatorId == operatorId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, operatorId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MessagingDefaultsTestCtrlRef
    on AutoDisposeNotifierProviderRef<MessagingTestUiState> {
  /// The parameter `operatorId` of this provider.
  String get operatorId;
}

class _MessagingDefaultsTestCtrlProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          MessagingDefaultsTestCtrl,
          MessagingTestUiState
        >
    with MessagingDefaultsTestCtrlRef {
  _MessagingDefaultsTestCtrlProviderElement(super.provider);

  @override
  String get operatorId =>
      (origin as MessagingDefaultsTestCtrlProvider).operatorId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
