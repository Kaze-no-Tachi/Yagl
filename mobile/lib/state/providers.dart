import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/repositories.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.create());

final authRepoProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));
final itemsRepoProvider =
    Provider<ItemsRepository>((ref) => ItemsRepository(ref.watch(apiClientProvider)));
final scanRepoProvider =
    Provider<ScanRepository>((ref) => ScanRepository(ref.watch(apiClientProvider)));
final importsRepoProvider =
    Provider<ImportsRepository>((ref) => ImportsRepository(ref.watch(apiClientProvider)));

/// Authentication state: true once a valid session exists.
class AuthController extends StateNotifier<AsyncValue<bool>> {
  AuthController(this._ref) : super(const AsyncValue.loading()) {
    _check();
  }
  final Ref _ref;

  Future<void> _check() async {
    try {
      final ok = await _ref.read(authRepoProvider).hasValidSession();
      state = AsyncValue.data(ok);
    } catch (_) {
      state = const AsyncValue.data(false);
    }
  }

  Future<void> login(String email, String password) async {
    await _ref.read(authRepoProvider).login(email, password);
    state = const AsyncValue.data(true);
  }

  Future<void> register(String email, String password) async {
    await _ref.read(authRepoProvider).register(email, password);
    state = const AsyncValue.data(true);
  }

  Future<void> logout() async {
    await _ref.read(authRepoProvider).logout();
    state = const AsyncValue.data(false);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<bool>>((ref) => AuthController(ref));

/// Platforms are fetched once and cached for filters / pickers.
final platformsProvider = FutureProvider<List<Platform>>(
    (ref) => ref.watch(itemsRepoProvider).platforms());

/// Current library filters; changing this refreshes [libraryProvider].
final filtersProvider = StateProvider<ItemFilters>((ref) => const ItemFilters());

/// The library list, reactive to [filtersProvider].
final libraryProvider = FutureProvider<List<Item>>((ref) {
  final filters = ref.watch(filtersProvider);
  return ref.watch(itemsRepoProvider).list(filters);
});

/// A single item detail, by id.
final itemProvider = FutureProvider.family<Item, int>(
    (ref, id) => ref.watch(itemsRepoProvider).get(id));
