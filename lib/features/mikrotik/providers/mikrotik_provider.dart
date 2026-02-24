import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';

// ── Singleton service provider ─────────────────────────────────────────────────
final mikrotikApiServiceProvider = Provider<MikroTikApiService>((ref) {
  final service = MikroTikApiService();
  ref.onDispose(() => service.disconnect());
  return service;
});

// ── Main state notifier ────────────────────────────────────────────────────────
class MikroTikNotifier extends StateNotifier<MikroTikState> {
  final MikroTikApiService _api;

  MikroTikNotifier(this._api) : super(const MikroTikState());

  // ── Connect ────────────────────────────────────────────────────────────────
  Future<void> connect(MikroTikConnection conn) async {
    state = state.copyWith(
      status: MikroTikConnectionStatus.connecting,
      isLoading: true,
    );
    try {
      await _api.connect(
        conn.host,
        conn.port,
        conn.username,
        conn.password,
      );
      state = state.copyWith(
        status: MikroTikConnectionStatus.connected,
        connection: conn,
        isLoading: false,
        errorMessage: null,
      );
      // Auto-load system info after connect
      await loadSystemInfo();
    } on MikroTikApiException catch (e) {
      state = state.copyWith(
        status: MikroTikConnectionStatus.error,
        errorMessage: e.message,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: MikroTikConnectionStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        isLoading: false,
      );
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    await _api.disconnect();
    state = const MikroTikState();
  }

  // ── System Info ─────────────────────────────────────────────────────────────
  Future<void> loadSystemInfo() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.getSystemResource();
      final identity = await _api.getSystemIdentity();
      state = state.copyWith(
        systemInfo: MikroTikSystemInfo.fromMap(res, identity),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // ── Interfaces ─────────────────────────────────────────────────────────────
  Future<void> loadInterfaces() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.getInterfaces();
      state = state.copyWith(
        interfaces: data.map(MikroTikInterface.fromMap).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleInterface(MikroTikInterface iface) async {
    try {
      if (iface.disabled) {
        await _api.enableInterface(iface.id);
      } else {
        await _api.disableInterface(iface.id);
      }
      await loadInterfaces();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ── Hotspot ────────────────────────────────────────────────────────────────
  Future<void> loadHotspot() async {
    state = state.copyWith(isLoading: true);
    try {
      final users = await _api.getHotspotUsers();
      final active = await _api.getHotspotActive();
      state = state.copyWith(
        hotspotUsers: users.map(MikroTikHotspotUser.fromMap).toList(),
        hotspotActive: active.map(MikroTikHotspotActive.fromMap).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addHotspotUser({
    required String name,
    required String password,
    String profile = 'default',
    String comment = '',
  }) async {
    try {
      await _api.addHotspotUser(
        name: name,
        password: password,
        profile: profile,
        comment: comment,
      );
      await loadHotspot();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> removeHotspotUser(String id) async {
    try {
      await _api.removeHotspotUser(id);
      await loadHotspot();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> kickHotspotActive(String id) async {
    try {
      await _api.hotspotKick(id);
      await loadHotspot();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> toggleHotspotUser(String id, bool disabled) async {
    try {
      await _api.setHotspotUserDisabled(id, disabled);
      await loadHotspot();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ── PPP ────────────────────────────────────────────────────────────────────
  Future<void> loadPPP() async {
    state = state.copyWith(isLoading: true);
    try {
      final secrets = await _api.getPPPSecrets();
      final active = await _api.getPPPActive();
      state = state.copyWith(
        pppSecrets: secrets.map(MikroTikPPPSecret.fromMap).toList(),
        pppActive: active.map(MikroTikPPPActive.fromMap).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addPPPSecret({
    required String name,
    required String password,
    String profile = 'default',
    String service = 'pppoe',
    String comment = '',
  }) async {
    try {
      await _api.addPPPSecret(
        name: name,
        password: password,
        profile: profile,
        service: service,
        comment: comment,
      );
      await loadPPP();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> removePPPSecret(String id) async {
    try {
      await _api.removePPPSecret(id);
      await loadPPP();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> disconnectPPPActive(String id) async {
    try {
      await _api.disconnectPPPActive(id);
      await loadPPP();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // ── IP & DHCP ──────────────────────────────────────────────────────────────
  Future<void> loadIpAndDhcp() async {
    state = state.copyWith(isLoading: true);
    try {
      final addresses = await _api.getIpAddresses();
      final leases = await _api.getDhcpLeases();
      state = state.copyWith(
        ipAddresses: addresses.map(MikroTikIpAddress.fromMap).toList(),
        dhcpLeases: leases.map(MikroTikDhcpLease.fromMap).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // ── Reboot ─────────────────────────────────────────────────────────────────
  Future<void> rebootRouter() async {
    try {
      await _api.reboot();
    } catch (_) {}
    await disconnect();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final mikrotikProvider =
    StateNotifierProvider<MikroTikNotifier, MikroTikState>((ref) {
  final api = ref.watch(mikrotikApiServiceProvider);
  return MikroTikNotifier(api);
});
