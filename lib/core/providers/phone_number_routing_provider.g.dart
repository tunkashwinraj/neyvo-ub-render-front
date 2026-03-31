// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phone_number_routing_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$phoneNumberRoutingCtrlHash() =>
    r'5a60e8e9eaa41d8afdabd2e553d9e7fadcfb319c';

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

abstract class _$PhoneNumberRoutingCtrl
    extends BuildlessAutoDisposeNotifier<PhoneNumberRoutingUiState> {
  late final String numberId;

  PhoneNumberRoutingUiState build(String numberId);
}

/// See also [PhoneNumberRoutingCtrl].
@ProviderFor(PhoneNumberRoutingCtrl)
const phoneNumberRoutingCtrlProvider = PhoneNumberRoutingCtrlFamily();

/// See also [PhoneNumberRoutingCtrl].
class PhoneNumberRoutingCtrlFamily extends Family<PhoneNumberRoutingUiState> {
  /// See also [PhoneNumberRoutingCtrl].
  const PhoneNumberRoutingCtrlFamily();

  /// See also [PhoneNumberRoutingCtrl].
  PhoneNumberRoutingCtrlProvider call(String numberId) {
    return PhoneNumberRoutingCtrlProvider(numberId);
  }

  @override
  PhoneNumberRoutingCtrlProvider getProviderOverride(
    covariant PhoneNumberRoutingCtrlProvider provider,
  ) {
    return call(provider.numberId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'phoneNumberRoutingCtrlProvider';
}

/// See also [PhoneNumberRoutingCtrl].
class PhoneNumberRoutingCtrlProvider
    extends
        AutoDisposeNotifierProviderImpl<
          PhoneNumberRoutingCtrl,
          PhoneNumberRoutingUiState
        > {
  /// See also [PhoneNumberRoutingCtrl].
  PhoneNumberRoutingCtrlProvider(String numberId)
    : this._internal(
        () => PhoneNumberRoutingCtrl()..numberId = numberId,
        from: phoneNumberRoutingCtrlProvider,
        name: r'phoneNumberRoutingCtrlProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$phoneNumberRoutingCtrlHash,
        dependencies: PhoneNumberRoutingCtrlFamily._dependencies,
        allTransitiveDependencies:
            PhoneNumberRoutingCtrlFamily._allTransitiveDependencies,
        numberId: numberId,
      );

  PhoneNumberRoutingCtrlProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.numberId,
  }) : super.internal();

  final String numberId;

  @override
  PhoneNumberRoutingUiState runNotifierBuild(
    covariant PhoneNumberRoutingCtrl notifier,
  ) {
    return notifier.build(numberId);
  }

  @override
  Override overrideWith(PhoneNumberRoutingCtrl Function() create) {
    return ProviderOverride(
      origin: this,
      override: PhoneNumberRoutingCtrlProvider._internal(
        () => create()..numberId = numberId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        numberId: numberId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    PhoneNumberRoutingCtrl,
    PhoneNumberRoutingUiState
  >
  createElement() {
    return _PhoneNumberRoutingCtrlProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PhoneNumberRoutingCtrlProvider &&
        other.numberId == numberId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, numberId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PhoneNumberRoutingCtrlRef
    on AutoDisposeNotifierProviderRef<PhoneNumberRoutingUiState> {
  /// The parameter `numberId` of this provider.
  String get numberId;
}

class _PhoneNumberRoutingCtrlProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          PhoneNumberRoutingCtrl,
          PhoneNumberRoutingUiState
        >
    with PhoneNumberRoutingCtrlRef {
  _PhoneNumberRoutingCtrlProviderElement(super.provider);

  @override
  String get numberId => (origin as PhoneNumberRoutingCtrlProvider).numberId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
