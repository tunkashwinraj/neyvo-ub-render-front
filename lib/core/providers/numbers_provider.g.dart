// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'numbers_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$numbersNotifierHash() => r'27fbf6f9692dc635123619c49884810f988987cb';

/// See also [NumbersNotifier].
@ProviderFor(NumbersNotifier)
final numbersNotifierProvider =
    AsyncNotifierProvider<NumbersNotifier, NumbersData>.internal(
      NumbersNotifier.new,
      name: r'numbersNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$numbersNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NumbersNotifier = AsyncNotifier<NumbersData>;
String _$numbersSyncBusyHash() => r'fe72cafe18f3fe5c2342e5831747fd56b371e094';

/// See also [NumbersSyncBusy].
@ProviderFor(NumbersSyncBusy)
final numbersSyncBusyProvider =
    AutoDisposeNotifierProvider<NumbersSyncBusy, bool>.internal(
      NumbersSyncBusy.new,
      name: r'numbersSyncBusyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$numbersSyncBusyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NumbersSyncBusy = AutoDisposeNotifier<bool>;
String _$numbersImportBusyHash() => r'46a4215b398319b6f102840829b61e6276b658e3';

/// See also [NumbersImportBusy].
@ProviderFor(NumbersImportBusy)
final numbersImportBusyProvider =
    AutoDisposeNotifierProvider<NumbersImportBusy, bool>.internal(
      NumbersImportBusy.new,
      name: r'numbersImportBusyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$numbersImportBusyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NumbersImportBusy = AutoDisposeNotifier<bool>;
String _$numbersAttachBusyHash() => r'60196a5366e333fc88e53e06e0b7ba053951d242';

/// See also [NumbersAttachBusy].
@ProviderFor(NumbersAttachBusy)
final numbersAttachBusyProvider =
    AutoDisposeNotifierProvider<NumbersAttachBusy, Map<String, bool>>.internal(
      NumbersAttachBusy.new,
      name: r'numbersAttachBusyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$numbersAttachBusyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NumbersAttachBusy = AutoDisposeNotifier<Map<String, bool>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
