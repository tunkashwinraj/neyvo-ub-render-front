// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agents_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$agentsNotifierHash() => r'65ba9ffa4f5e155c36487ab121c1f66ebbcbbecc';

/// See also [AgentsNotifier].
@ProviderFor(AgentsNotifier)
final agentsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      AgentsNotifier,
      List<AgentProfile>
    >.internal(
      AgentsNotifier.new,
      name: r'agentsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$agentsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AgentsNotifier = AutoDisposeAsyncNotifier<List<AgentProfile>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
