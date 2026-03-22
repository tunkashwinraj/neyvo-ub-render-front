import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../neyvo_pulse_api.dart';

part 'wallet_page_provider.g.dart';

class WalletPageUiState {
  const WalletPageUiState({
    this.loading = true,
    this.error,
    this.wallet,
    this.transactions = const [],
    this.offset = 0,
    this.typeFilter = 'all',
    this.loadingMore = false,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic>? wallet;
  final List<Map<String, dynamic>> transactions;
  final int offset;
  final String typeFilter;
  final bool loadingMore;

  static const int pageSize = 30;

  WalletPageUiState copyWith({
    bool? loading,
    String? error,
    Map<String, dynamic>? wallet,
    List<Map<String, dynamic>>? transactions,
    int? offset,
    String? typeFilter,
    bool? loadingMore,
    bool clearError = false,
    bool clearWallet = false,
  }) {
    return WalletPageUiState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      wallet: clearWallet ? null : (wallet ?? this.wallet),
      transactions: transactions ?? this.transactions,
      offset: offset ?? this.offset,
      typeFilter: typeFilter ?? this.typeFilter,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

@riverpod
class WalletPageCtrl extends _$WalletPageCtrl {
  @override
  WalletPageUiState build() => const WalletPageUiState();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true, offset: 0);
    try {
      final results = await Future.wait([
        NeyvoPulseApi.getBillingWallet(shellScoped: true),
        NeyvoPulseApi.getBillingTransactions(
          limit: WalletPageUiState.pageSize,
          offset: 0,
          type: state.typeFilter,
        ),
      ]);
      final txRes = results[1] as Map<String, dynamic>;
      final list = txRes['transactions'] as List<dynamic>?;
      state = state.copyWith(
        loading: false,
        wallet: results[0] as Map<String, dynamic>,
        transactions: list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
        offset: 0,
      );
    } catch (e) {
      if (isPulseRequestCancelled(e)) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.transactions.length < state.offset + WalletPageUiState.pageSize) return;
    state = state.copyWith(loadingMore: true);
    try {
      final nextOffset = state.offset + WalletPageUiState.pageSize;
      final res = await NeyvoPulseApi.getBillingTransactions(
        limit: WalletPageUiState.pageSize,
        offset: nextOffset,
        type: state.typeFilter,
      );
      final list =
          (res['transactions'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      state = state.copyWith(
        transactions: [...state.transactions, ...list],
        offset: nextOffset,
        loadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> setTypeFilter(String type) async {
    if (state.typeFilter == type) return;
    state = state.copyWith(typeFilter: type, loading: true, offset: 0);
    try {
      final res = await NeyvoPulseApi.getBillingTransactions(
        limit: WalletPageUiState.pageSize,
        offset: 0,
        type: type,
      );
      final list =
          (res['transactions'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      state = state.copyWith(transactions: list, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
