// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$billingSummaryHash() => r'a4a88f01fb731f3787c11ffffa04d04ad11940d0';

/// See also [billingSummary].
@ProviderFor(billingSummary)
final billingSummaryProvider =
    AutoDisposeFutureProvider<BillingSummaryModel>.internal(
      billingSummary,
      name: r'billingSummaryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$billingSummaryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BillingSummaryRef = AutoDisposeFutureProviderRef<BillingSummaryModel>;
String _$callUsageChartHash() => r'bd81e2df7f690534987883d54672cc43b73640e6';

/// See also [callUsageChart].
@ProviderFor(callUsageChart)
final callUsageChartProvider =
    AutoDisposeFutureProvider<List<CallUsagePoint>>.internal(
      callUsageChart,
      name: r'callUsageChartProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$callUsageChartHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CallUsageChartRef = AutoDisposeFutureProviderRef<List<CallUsagePoint>>;
String _$stripeCheckoutUrlHash() => r'91323210b9339464faa3eee07c09248e1d56f11b';

/// See also [stripeCheckoutUrl].
@ProviderFor(stripeCheckoutUrl)
final stripeCheckoutUrlProvider = AutoDisposeFutureProvider<String>.internal(
  stripeCheckoutUrl,
  name: r'stripeCheckoutUrlProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$stripeCheckoutUrlHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StripeCheckoutUrlRef = AutoDisposeFutureProviderRef<String>;
String _$billingNotifierHash() => r'18a93930f166f159b53d268fa98ea1322c536026';

/// See also [BillingNotifier].
@ProviderFor(BillingNotifier)
final billingNotifierProvider =
    AutoDisposeAsyncNotifierProvider<BillingNotifier, BillingData>.internal(
      BillingNotifier.new,
      name: r'billingNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$billingNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BillingNotifier = AutoDisposeAsyncNotifier<BillingData>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
