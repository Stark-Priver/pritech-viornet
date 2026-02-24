// MikroTik Feature — Data Models

class MikroTikConnection {
  final String host;
  final int port;
  final String username;
  final String password;

  const MikroTikConnection({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  MikroTikConnection copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return MikroTikConnection(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

enum MikroTikConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class MikroTikState {
  final MikroTikConnectionStatus status;
  final MikroTikConnection? connection;
  final String? errorMessage;
  final MikroTikSystemInfo? systemInfo;
  final List<MikroTikInterface> interfaces;
  final List<MikroTikHotspotUser> hotspotUsers;
  final List<MikroTikHotspotActive> hotspotActive;
  final List<MikroTikPPPSecret> pppSecrets;
  final List<MikroTikPPPActive> pppActive;
  final List<MikroTikIpAddress> ipAddresses;
  final List<MikroTikDhcpLease> dhcpLeases;
  final List<MikroTikHotspotProfile> hotspotProfiles;
  final bool isLoading;

  const MikroTikState({
    this.status = MikroTikConnectionStatus.disconnected,
    this.connection,
    this.errorMessage,
    this.systemInfo,
    this.interfaces = const [],
    this.hotspotUsers = const [],
    this.hotspotActive = const [],
    this.pppSecrets = const [],
    this.pppActive = const [],
    this.ipAddresses = const [],
    this.dhcpLeases = const [],
    this.hotspotProfiles = const [],
    this.isLoading = false,
  });

  bool get isConnected => status == MikroTikConnectionStatus.connected;

  MikroTikState copyWith({
    MikroTikConnectionStatus? status,
    MikroTikConnection? connection,
    String? errorMessage,
    MikroTikSystemInfo? systemInfo,
    List<MikroTikInterface>? interfaces,
    List<MikroTikHotspotUser>? hotspotUsers,
    List<MikroTikHotspotActive>? hotspotActive,
    List<MikroTikPPPSecret>? pppSecrets,
    List<MikroTikPPPActive>? pppActive,
    List<MikroTikIpAddress>? ipAddresses,
    List<MikroTikDhcpLease>? dhcpLeases,
    List<MikroTikHotspotProfile>? hotspotProfiles,
    bool? isLoading,
  }) {
    return MikroTikState(
      status: status ?? this.status,
      connection: connection ?? this.connection,
      errorMessage: errorMessage,
      systemInfo: systemInfo ?? this.systemInfo,
      interfaces: interfaces ?? this.interfaces,
      hotspotUsers: hotspotUsers ?? this.hotspotUsers,
      hotspotActive: hotspotActive ?? this.hotspotActive,
      pppSecrets: pppSecrets ?? this.pppSecrets,
      pppActive: pppActive ?? this.pppActive,
      ipAddresses: ipAddresses ?? this.ipAddresses,
      dhcpLeases: dhcpLeases ?? this.dhcpLeases,
      hotspotProfiles: hotspotProfiles ?? this.hotspotProfiles,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── System Info ───────────────────────────────────────────────────────────────
class MikroTikSystemInfo {
  final String identity;
  final String version;
  final String board;
  final String cpu;
  final String uptime;
  final String totalMemory;
  final String freeMemory;
  final String cpuLoad;
  final String totalHdd;
  final String freeHdd;
  final String architecture;

  const MikroTikSystemInfo({
    this.identity = '',
    this.version = '',
    this.board = '',
    this.cpu = '',
    this.uptime = '',
    this.totalMemory = '',
    this.freeMemory = '',
    this.cpuLoad = '',
    this.totalHdd = '',
    this.freeHdd = '',
    this.architecture = '',
  });

  factory MikroTikSystemInfo.fromMap(
      Map<String, String> res, Map<String, String> identity) {
    return MikroTikSystemInfo(
      identity: identity['name'] ?? '',
      version: res['version'] ?? '',
      board: res['board-name'] ?? '',
      cpu: res['cpu'] ?? '',
      uptime: res['uptime'] ?? '',
      totalMemory: res['total-memory'] ?? '',
      freeMemory: res['free-memory'] ?? '',
      cpuLoad: res['cpu-load'] ?? '',
      totalHdd: res['total-hdd-space'] ?? '',
      freeHdd: res['free-hdd-space'] ?? '',
      architecture: res['architecture-name'] ?? '',
    );
  }

  String get memoryUsagePercent {
    final total = int.tryParse(totalMemory) ?? 0;
    final free = int.tryParse(freeMemory) ?? 0;
    if (total == 0) return '0';
    return ((1 - free / total) * 100).toStringAsFixed(1);
  }

  String get hddUsagePercent {
    final total = int.tryParse(totalHdd) ?? 0;
    final free = int.tryParse(freeHdd) ?? 0;
    if (total == 0) return '0';
    return ((1 - free / total) * 100).toStringAsFixed(1);
  }

  static String formatBytes(String bytesStr) {
    final bytes = int.tryParse(bytesStr) ?? 0;
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

// ── Interface ─────────────────────────────────────────────────────────────────
class MikroTikInterface {
  final String id;
  final String name;
  final String type;
  final String macAddress;
  final bool running;
  final bool disabled;
  final String comment;
  final String txByte;
  final String rxByte;

  const MikroTikInterface({
    this.id = '',
    this.name = '',
    this.type = '',
    this.macAddress = '',
    this.running = false,
    this.disabled = false,
    this.comment = '',
    this.txByte = '',
    this.rxByte = '',
  });

  factory MikroTikInterface.fromMap(Map<String, String> map) {
    return MikroTikInterface(
      id: map['.id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      macAddress: map['mac-address'] ?? '',
      running: map['running'] == 'true',
      disabled: map['disabled'] == 'true',
      comment: map['comment'] ?? '',
      txByte: map['tx-byte'] ?? '0',
      rxByte: map['rx-byte'] ?? '0',
    );
  }
}

// ── Hotspot ───────────────────────────────────────────────────────────────────
class MikroTikHotspotUser {
  final String id;
  final String name;
  final String password;
  final String profile;
  final String comment;
  final bool disabled;
  final String limitUptime;
  final String limitBytesTotal;

  const MikroTikHotspotUser({
    this.id = '',
    this.name = '',
    this.password = '',
    this.profile = '',
    this.comment = '',
    this.disabled = false,
    this.limitUptime = '',
    this.limitBytesTotal = '',
  });

  factory MikroTikHotspotUser.fromMap(Map<String, String> map) {
    return MikroTikHotspotUser(
      id: map['.id'] ?? '',
      name: map['name'] ?? '',
      password: map['password'] ?? '',
      profile: map['profile'] ?? '',
      comment: map['comment'] ?? '',
      disabled: map['disabled'] == 'true',
      limitUptime: map['limit-uptime'] ?? '',
      limitBytesTotal: map['limit-bytes-total'] ?? '',
    );
  }
}

class MikroTikHotspotActive {
  final String id;
  final String user;
  final String address;
  final String macAddress;
  final String uptime;
  final String sessionTimeLeft;
  final String rxByte;
  final String txByte;

  const MikroTikHotspotActive({
    this.id = '',
    this.user = '',
    this.address = '',
    this.macAddress = '',
    this.uptime = '',
    this.sessionTimeLeft = '',
    this.rxByte = '',
    this.txByte = '',
  });

  factory MikroTikHotspotActive.fromMap(Map<String, String> map) {
    return MikroTikHotspotActive(
      id: map['.id'] ?? '',
      user: map['user'] ?? '',
      address: map['address'] ?? '',
      macAddress: map['mac-address'] ?? '',
      uptime: map['uptime'] ?? '',
      sessionTimeLeft: map['session-time-left'] ?? '',
      rxByte: map['bytes-in'] ?? '0',
      txByte: map['bytes-out'] ?? '0',
    );
  }
}

// ── PPP ───────────────────────────────────────────────────────────────────────
class MikroTikPPPSecret {
  final String id;
  final String name;
  final String password;
  final String profile;
  final String service;
  final String comment;
  final bool disabled;
  final String localAddress;
  final String remoteAddress;

  const MikroTikPPPSecret({
    this.id = '',
    this.name = '',
    this.password = '',
    this.profile = '',
    this.service = '',
    this.comment = '',
    this.disabled = false,
    this.localAddress = '',
    this.remoteAddress = '',
  });

  factory MikroTikPPPSecret.fromMap(Map<String, String> map) {
    return MikroTikPPPSecret(
      id: map['.id'] ?? '',
      name: map['name'] ?? '',
      password: map['password'] ?? '',
      profile: map['profile'] ?? '',
      service: map['service'] ?? '',
      comment: map['comment'] ?? '',
      disabled: map['disabled'] == 'true',
      localAddress: map['local-address'] ?? '',
      remoteAddress: map['remote-address'] ?? '',
    );
  }
}

class MikroTikPPPActive {
  final String id;
  final String name;
  final String address;
  final String uptime;
  final String service;
  final String callerID;

  const MikroTikPPPActive({
    this.id = '',
    this.name = '',
    this.address = '',
    this.uptime = '',
    this.service = '',
    this.callerID = '',
  });

  factory MikroTikPPPActive.fromMap(Map<String, String> map) {
    return MikroTikPPPActive(
      id: map['.id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      uptime: map['uptime'] ?? '',
      service: map['service'] ?? '',
      callerID: map['caller-id'] ?? '',
    );
  }
}

// ── IP ────────────────────────────────────────────────────────────────────────
class MikroTikIpAddress {
  final String id;
  final String address;
  final String network;
  final String interface;
  final bool disabled;
  final bool dynamic;

  const MikroTikIpAddress({
    this.id = '',
    this.address = '',
    this.network = '',
    this.interface = '',
    this.disabled = false,
    this.dynamic = false,
  });

  factory MikroTikIpAddress.fromMap(Map<String, String> map) {
    return MikroTikIpAddress(
      id: map['.id'] ?? '',
      address: map['address'] ?? '',
      network: map['network'] ?? '',
      interface: map['interface'] ?? '',
      disabled: map['disabled'] == 'true',
      dynamic: map['dynamic'] == 'true',
    );
  }
}

// ── Hotspot Profile ───────────────────────────────────────────────────────────
class MikroTikHotspotProfile {
  final String id;
  final String name;
  final String rateLimit;
  final String sessionTimeout;
  final String keepaliveTimeout;
  final String sharedUsers;
  final String addressPool;
  final int userCount; // computed from hotspot users list

  const MikroTikHotspotProfile({
    this.id = '',
    this.name = '',
    this.rateLimit = '',
    this.sessionTimeout = '',
    this.keepaliveTimeout = '',
    this.sharedUsers = '',
    this.addressPool = '',
    this.userCount = 0,
  });

  factory MikroTikHotspotProfile.fromMap(Map<String, String> map,
      {int userCount = 0}) {
    return MikroTikHotspotProfile(
      id: map['.id'] ?? '',
      name: map['name'] ?? '',
      rateLimit: map['rate-limit'] ?? '',
      sessionTimeout: map['session-timeout'] ?? '',
      keepaliveTimeout: map['keepalive-timeout'] ?? '',
      sharedUsers: map['shared-users'] ?? '1',
      addressPool: map['address-pool'] ?? '',
      userCount: userCount,
    );
  }

  MikroTikHotspotProfile withUserCount(int count) {
    return MikroTikHotspotProfile(
      id: id,
      name: name,
      rateLimit: rateLimit,
      sessionTimeout: sessionTimeout,
      keepaliveTimeout: keepaliveTimeout,
      sharedUsers: sharedUsers,
      addressPool: addressPool,
      userCount: count,
    );
  }

  /// Parse rate limit string like "5M/10M" into readable form
  String get rateLimitDisplay {
    if (rateLimit.isEmpty) return 'Unlimited';
    final parts = rateLimit.split('/');
    if (parts.length == 2) {
      return '↑ ${parts[0]}  ↓ ${parts[1]}';
    }
    return rateLimit;
  }
}

// ── Bulk Voucher Generation Result ────────────────────────────────────────────
class VoucherGenerationResult {
  final int total;
  final int succeeded;
  final int failed;
  final List<String> generatedCodes;
  final List<String> errors;
  final String batchId;

  const VoucherGenerationResult({
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.generatedCodes,
    required this.errors,
    required this.batchId,
  });
}

// ── DHCP Lease ────────────────────────────────────────────────────────────────
class MikroTikDhcpLease {
  final String id;
  final String address;
  final String macAddress;
  final String hostname;
  final String status;
  final String expiresAfter;
  final bool dynamic;

  const MikroTikDhcpLease({
    this.id = '',
    this.address = '',
    this.macAddress = '',
    this.hostname = '',
    this.status = '',
    this.expiresAfter = '',
    this.dynamic = false,
  });

  factory MikroTikDhcpLease.fromMap(Map<String, String> map) {
    return MikroTikDhcpLease(
      id: map['.id'] ?? '',
      address: map['address'] ?? '',
      macAddress: map['mac-address'] ?? '',
      hostname: map['host-name'] ?? '',
      status: map['status'] ?? '',
      expiresAfter: map['expires-after'] ?? '',
      dynamic: map['dynamic'] == 'true',
    );
  }
}
