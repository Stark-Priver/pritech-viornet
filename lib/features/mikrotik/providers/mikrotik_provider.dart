import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/voucher_service.dart';
import '../../../core/providers/providers.dart';
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
  final VoucherService _voucherService;
  final _uuid = const Uuid();
  final _rand = Random.secure();

  MikroTikNotifier(this._api, this._voucherService)
      : super(const MikroTikState());

  // ── Code generator ─────────────────────────────────────────────────────────
  String _generateCode(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(length, (_) => chars[_rand.nextInt(chars.length)])
        .join();
  }

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

  // ── Hotspot Users ──────────────────────────────────────────────────────────
  Future<void> loadHotspot() async {
    state = state.copyWith(isLoading: true);
    try {
      final users = await _api.getHotspotUsers();
      final active = await _api.getHotspotActive();
      final userList = users.map(MikroTikHotspotUser.fromMap).toList();
      state = state.copyWith(
        hotspotUsers: userList,
        hotspotActive: active.map(MikroTikHotspotActive.fromMap).toList(),
        isLoading: false,
      );
      // Recompute per-profile user counts if profiles already loaded
      if (state.hotspotProfiles.isNotEmpty) {
        _recomputeProfileCounts(userList);
      }
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

  // ── Hotspot Profiles ───────────────────────────────────────────────────────
  Future<void> loadProfiles() async {
    state = state.copyWith(isLoading: true);
    try {
      final profileData = await _api.getHotspotProfiles();
      List<MikroTikHotspotUser> users = state.hotspotUsers;
      if (users.isEmpty) {
        final raw = await _api.getHotspotUsers();
        users = raw.map(MikroTikHotspotUser.fromMap).toList();
        state = state.copyWith(hotspotUsers: users);
      }
      final profiles = profileData.map((p) {
        final profile = MikroTikHotspotProfile.fromMap(p);
        final count = users.where((u) => u.profile == profile.name).length;
        return profile.withUserCount(count);
      }).toList();
      state = state.copyWith(hotspotProfiles: profiles, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void _recomputeProfileCounts(List<MikroTikHotspotUser> users) {
    final updated = state.hotspotProfiles.map((p) {
      final count = users.where((u) => u.profile == p.name).length;
      return p.withUserCount(count);
    }).toList();
    state = state.copyWith(hotspotProfiles: updated);
  }

  Future<void> addHotspotProfile({
    required String name,
    String rateLimit = '',
    String sessionTimeout = '',
    String sharedUsers = '1',
    String addressPool = '',
  }) async {
    try {
      await _api.addHotspotProfile(
        name: name,
        rateLimit: rateLimit,
        sessionTimeout: sessionTimeout,
        sharedUsers: sharedUsers,
        addressPool: addressPool,
      );
      await loadProfiles();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> removeHotspotProfile(String id) async {
    try {
      await _api.removeHotspotProfile(id);
      await loadProfiles();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> editHotspotProfile(
    String id, {
    String? rateLimit,
    String? sessionTimeout,
    String? sharedUsers,
  }) async {
    try {
      await _api.editHotspotProfile(
        id,
        rateLimit: rateLimit,
        sessionTimeout: sessionTimeout,
        sharedUsers: sharedUsers,
      );
      await loadProfiles();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  // ── Bulk Voucher Generation ────────────────────────────────────────────────
  /// Generates [count] vouchers tied to [profileName].
  /// Each voucher: code = username = password (same random alphanumeric value).
  /// Creates hotspot users on the MikroTik AND saves each to the ViorNet DB.
  Future<VoucherGenerationResult> generateBulkVouchers({
    required String profileName,
    required int count,
    required int codeLength,
    int? siteId,
    double? price,
    String? validity,
    String? speed,
    void Function(int done, int total)? onProgress,
  }) async {
    final batchId = _uuid.v4();
    final List<String> succeeded = [];
    final List<String> errors = [];

    // Pre-generate unique codes (avoid collisions with existing users)
    final existingNames = state.hotspotUsers.map((u) => u.name).toSet();
    final codeSet = <String>{};
    while (codeSet.length < count) {
      final c = _generateCode(codeLength);
      if (!existingNames.contains(c)) codeSet.add(c);
    }
    final codes = codeSet.toList();

    for (int i = 0; i < codes.length; i++) {
      final code = codes[i];
      onProgress?.call(i, count);

      // Step 1 – Create hotspot user on MikroTik (code = username = password)
      try {
        await _api.addHotspotUser(
          name: code,
          password: code,
          profile: profileName,
          comment: 'ViorNet batch $batchId',
        );
      } catch (e) {
        errors.add('MikroTik [$code]: $e');
        continue;
      }

      // Step 2 – Persist to ViorNet database
      try {
        await _voucherService.addVoucher(
          code: code,
          siteId: siteId,
          price: price,
          validity: validity,
          speed: speed,
          qrCodeData: code,
          batchId: batchId,
          username: code,
          password: code,
        );
        succeeded.add(code);
      } catch (e) {
        // Keep MikroTik and DB in sync — roll back the router user
        try {
          await _api.removeHotspotUser(code);
        } catch (_) {}
        errors.add('DB [$code]: $e');
      }
    }

    onProgress?.call(count, count);
    await loadHotspot();
    await loadProfiles();

    return VoucherGenerationResult(
      total: count,
      succeeded: succeeded.length,
      failed: errors.length,
      generatedCodes: succeeded,
      errors: errors,
      batchId: batchId,
    );
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
  final voucherService = ref.watch(voucherServiceProvider);
  return MikroTikNotifier(api, voucherService);
});
