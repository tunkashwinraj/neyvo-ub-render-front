import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/neyvo_api.dart';

part 'backup_rollback_provider.g.dart';

class BackupRelease {
  const BackupRelease({
    required this.tag,
    required this.name,
    required this.createdAt,
    required this.htmlUrl,
    required this.assetNames,
  });

  final String tag;
  final String name;
  final String createdAt;
  final String htmlUrl;
  final List<String> assetNames;
}

class BackupRollbackUiState {
  const BackupRollbackUiState({
    this.loading = true,
    this.error,
    this.front = const [],
    this.back = const [],
  });

  final bool loading;
  final String? error;
  final List<BackupRelease> front;
  final List<BackupRelease> back;

  BackupRollbackUiState copyWith({
    bool? loading,
    String? error,
    List<BackupRelease>? front,
    List<BackupRelease>? back,
    bool clearError = false,
  }) {
    return BackupRollbackUiState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      front: front ?? this.front,
      back: back ?? this.back,
    );
  }
}

@riverpod
class BackupRollback extends _$BackupRollback {
  static const _frontRepo = 'tunkashwinraj/Goodwin_Neyvo_Front';
  static const _backRepo = 'tunkashwinraj/Goodwin_Neyvo_Back';
  static const String _kAdminsCsv = String.fromEnvironment('INTERNAL_BACKUP_ADMINS', defaultValue: '');

  @override
  BackupRollbackUiState build() {
    return const BackupRollbackUiState();
  }

  bool get isAuthorized {
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim().toLowerCase();
    if (email.isEmpty) return false;
    final allowed = _kAdminsCsv
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (allowed.isEmpty) return false;
    return allowed.contains(email);
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      if (!isAuthorized) {
        state = state.copyWith(loading: false, front: const [], back: const []);
        return;
      }
      final res = await NeyvoApi.getJsonMap('/api/pulse/internal/backups');
      if (res['ok'] != true) {
        throw Exception(res['error']?.toString() ?? 'Failed to load backups');
      }
      final repos = res['repos'];
      if (repos is! Map) throw Exception('Invalid backups response');
      final front = _parseRepoResult(repos[_frontRepo]);
      final back = _parseRepoResult(repos[_backRepo]);
      state = state.copyWith(loading: false, front: front, back: back);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  List<BackupRelease> _parseRepoResult(dynamic v) {
    final m = (v is Map) ? v : null;
    final ok = m?['ok'] == true;
    if (!ok) {
      final status = m?['status']?.toString();
      final body = m?['body']?.toString();
      throw Exception('Backups API failed${status != null ? " ($status)" : ""}: ${body ?? m?['error'] ?? 'unknown'}');
    }
    final list = m?['releases'];
    if (list is! List) return const [];
    final out = <BackupRelease>[];
    for (final item in list) {
      if (item is! Map) continue;
      final tag = (item['tag'] ?? '').toString();
      if (!tag.startsWith('backup-')) continue;
      final htmlUrl = (item['html_url'] ?? '').toString();
      final name = (item['name'] ?? tag).toString();
      final createdAt = (item['created_at'] ?? '').toString();
      final assetNames = <String>[];
      final a = item['asset_names'];
      if (a is List) {
        for (final x in a) {
          final s = x?.toString() ?? '';
          if (s.isNotEmpty) assetNames.add(s);
        }
      }
      out.add(BackupRelease(tag: tag, name: name, createdAt: createdAt, htmlUrl: htmlUrl, assetNames: assetNames));
    }
    out.sort((a, b) => b.tag.compareTo(a.tag));
    return out;
  }
}
