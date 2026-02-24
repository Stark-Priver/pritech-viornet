// MikroTik RouterOS API Service (TCP Port 8728)
// Implements the RouterOS API sentence/word protocol.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

typedef MikroTikSentence = List<String>;
typedef MikroTikReply = List<Map<String, String>>;

class MikroTikApiException implements Exception {
  final String message;
  const MikroTikApiException(this.message);

  @override
  String toString() => 'MikroTikApiException: $message';
}

class MikroTikApiService {
  Socket? _socket;
  final List<int> _buffer = [];
  final StreamController<MikroTikSentence> _sentenceController =
      StreamController.broadcast();
  StreamSubscription? _socketSub;

  bool get isConnected => _socket != null;

  // ── Connect & Login ──────────────────────────────────────────────────────────
  Future<void> connect(
    String host,
    int port,
    String username,
    String password, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await disconnect();
    _socket = await Socket.connect(host, port, timeout: timeout);
    _buffer.clear();

    _socketSub = _socket!.listen(
      _onData,
      onError: (_) => disconnect(),
      onDone: () => disconnect(),
    );

    await _login(username, password);
  }

  Future<void> disconnect() async {
    await _socketSub?.cancel();
    _socketSub = null;
    await _socket?.close();
    _socket = null;
    _buffer.clear();
  }

  // ── Auto-detecting login ──────────────────────────────────────────────────────
  // Probe with a bare /login (no params).
  //   • If the reply contains =ret= → legacy MD5 mode (RouterOS < 6.43)
  //   • If !done arrives with no rows   → modern plain-text mode (RouterOS 6.43+),
  //     send a second /login with name + password.
  Future<void> _login(String username, String password) async {
    // Step 1: probe
    final probe = await sendCommand('/login');

    final ret = probe.firstOrNull?['ret'];

    if (ret != null && ret.isNotEmpty) {
      // ── Legacy MD5 path ────────────────────────────────────────────────────
      // ret is a hex challenge: MD5(0x00 + password + challenge_bytes)
      final challengeBytes = _hexToBytes(ret);
      final toHash = [0x00, ...utf8.encode(password), ...challengeBytes];
      final hash = md5.convert(toHash).toString();

      final reply = await sendCommand('/login', params: {
        'name': username,
        'response': '00$hash',
      });

      final first = reply.firstOrNull;
      if (first != null && first.containsKey('message')) {
        throw MikroTikApiException(first['message']!);
      }
    } else {
      // ── Modern plain-text path (6.43+) ────────────────────────────────────
      // Probe returned !done with no challenge; send credentials now.
      final reply = await sendCommand('/login', params: {
        'name': username,
        'password': password,
      });

      final first = reply.firstOrNull;
      if (first != null && first.containsKey('message')) {
        throw MikroTikApiException(first['message']!);
      }
    }
  }

  // ── Send a command & collect reply ───────────────────────────────────────────
  Future<MikroTikReply> sendCommand(
    String command, {
    Map<String, String> params = const {},
    List<String> queries = const [],
  }) async {
    if (_socket == null) {
      throw const MikroTikApiException('Not connected');
    }

    final words = <String>[command];
    for (final entry in params.entries) {
      words.add('=${entry.key}=${entry.value}');
    }
    for (final q in queries) {
      words.add('?$q');
    }
    _writeSentence(words);

    // Collect sentences until !done or !trap or !fatal
    final rows = <Map<String, String>>[];
    await for (final sentence in _sentenceController.stream.timeout(
      const Duration(seconds: 15),
    )) {
      if (sentence.isEmpty) continue;
      final tag = sentence.first;
      if (tag == '!done') break;
      if (tag == '!trap' || tag == '!fatal') {
        final msg = _sentenceToMap(sentence)['message'] ?? tag;
        throw MikroTikApiException(msg);
      }
      if (tag == '!re') {
        rows.add(_sentenceToMap(sentence));
      }
    }
    return rows;
  }

  // ── Write a sentence to the socket ───────────────────────────────────────────
  void _writeSentence(List<String> words) {
    final bytes = <int>[];
    for (final word in words) {
      final encoded = utf8.encode(word);
      bytes.addAll(_encodeLength(encoded.length));
      bytes.addAll(encoded);
    }
    bytes.add(0); // empty word = end of sentence
    _socket!.add(bytes);
  }

  // ── Parse incoming data ───────────────────────────────────────────────────────
  void _onData(List<int> data) {
    _buffer.addAll(data);
    _parseBuffer();
  }

  void _parseBuffer() {
    while (true) {
      if (_buffer.isEmpty) break;
      // Parse one sentence
      final sentence = <String>[];
      var pos = 0;
      var valid = true;

      while (pos < _buffer.length) {
        final lengthResult = _decodeLength(_buffer, pos);
        if (lengthResult == null) {
          valid = false;
          break;
        }
        final wordLen = lengthResult.$1;
        final headerLen = lengthResult.$2;

        if (wordLen == 0) {
          // End of sentence
          pos += headerLen;
          break;
        }

        if (pos + headerLen + wordLen > _buffer.length) {
          valid = false;
          break;
        }

        final wordBytes =
            _buffer.sublist(pos + headerLen, pos + headerLen + wordLen);
        sentence.add(utf8.decode(wordBytes, allowMalformed: true));
        pos += headerLen + wordLen;
      }

      if (!valid) break;
      _buffer.removeRange(0, pos);
      if (sentence.isNotEmpty) {
        _sentenceController.add(sentence);
      }
    }
  }

  // ── Length encoding (RouterOS protocol) ──────────────────────────────────────
  List<int> _encodeLength(int len) {
    if (len < 0x80) {
      return [len];
    } else if (len < 0x4000) {
      return [(len >> 8) | 0x80, len & 0xFF];
    } else if (len < 0x200000) {
      return [(len >> 16) | 0xC0, (len >> 8) & 0xFF, len & 0xFF];
    } else if (len < 0x10000000) {
      return [
        (len >> 24) | 0xE0,
        (len >> 16) & 0xFF,
        (len >> 8) & 0xFF,
        len & 0xFF,
      ];
    } else {
      return [
        0xF0,
        (len >> 24) & 0xFF,
        (len >> 16) & 0xFF,
        (len >> 8) & 0xFF,
        len & 0xFF,
      ];
    }
  }

  (int, int)? _decodeLength(List<int> buf, int pos) {
    if (pos >= buf.length) return null;
    final b = buf[pos] & 0xFF;
    if ((b & 0x80) == 0) {
      return (b, 1);
    } else if ((b & 0xC0) == 0x80) {
      if (pos + 1 >= buf.length) return null;
      return (((b & 0x3F) << 8) | (buf[pos + 1] & 0xFF), 2);
    } else if ((b & 0xE0) == 0xC0) {
      if (pos + 2 >= buf.length) return null;
      return (
        ((b & 0x1F) << 16) |
            ((buf[pos + 1] & 0xFF) << 8) |
            (buf[pos + 2] & 0xFF),
        3,
      );
    } else if ((b & 0xF0) == 0xE0) {
      if (pos + 3 >= buf.length) return null;
      return (
        ((b & 0x0F) << 24) |
            ((buf[pos + 1] & 0xFF) << 16) |
            ((buf[pos + 2] & 0xFF) << 8) |
            (buf[pos + 3] & 0xFF),
        4,
      );
    } else if (b == 0xF0) {
      if (pos + 4 >= buf.length) return null;
      return (
        ((buf[pos + 1] & 0xFF) << 24) |
            ((buf[pos + 2] & 0xFF) << 16) |
            ((buf[pos + 3] & 0xFF) << 8) |
            (buf[pos + 4] & 0xFF),
        5,
      );
    }
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  Map<String, String> _sentenceToMap(List<String> sentence) {
    final map = <String, String>{};
    for (final word in sentence.skip(1)) {
      if (word.startsWith('=')) {
        final eqIdx = word.indexOf('=', 1);
        if (eqIdx != -1) {
          final key = word.substring(1, eqIdx);
          final value = word.substring(eqIdx + 1);
          map[key] = value;
        }
      }
    }
    return map;
  }

  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  // ── High-level API helpers ────────────────────────────────────────────────────
  Future<Map<String, String>> getFirstReply(
    String command, {
    Map<String, String> params = const {},
  }) async {
    final reply = await sendCommand(command, params: params);
    return reply.firstOrNull ?? {};
  }

  /// System resource info
  Future<Map<String, String>> getSystemResource() async {
    return getFirstReply('/system/resource/print');
  }

  /// System identity
  Future<Map<String, String>> getSystemIdentity() async {
    return getFirstReply('/system/identity/print');
  }

  /// List all interfaces
  Future<MikroTikReply> getInterfaces() async {
    return sendCommand('/interface/print');
  }

  /// List all hotspot users
  Future<MikroTikReply> getHotspotUsers() async {
    return sendCommand('/ip/hotspot/user/print');
  }

  /// List active hotspot sessions
  Future<MikroTikReply> getHotspotActive() async {
    return sendCommand('/ip/hotspot/active/print');
  }

  /// Kick a hotspot active session
  Future<void> hotspotKick(String id) async {
    await sendCommand('/ip/hotspot/active/remove', params: {'.id': id});
  }

  /// Add hotspot user
  Future<void> addHotspotUser({
    required String name,
    required String password,
    String profile = 'default',
    String comment = '',
  }) async {
    await sendCommand('/ip/hotspot/user/add', params: {
      'name': name,
      'password': password,
      'profile': profile,
      if (comment.isNotEmpty) 'comment': comment,
    });
  }

  /// Remove hotspot user
  Future<void> removeHotspotUser(String id) async {
    await sendCommand('/ip/hotspot/user/remove', params: {'.id': id});
  }

  /// Toggle hotspot user disabled state
  Future<void> setHotspotUserDisabled(String id, bool disabled) async {
    await sendCommand('/ip/hotspot/user/set', params: {
      '.id': id,
      'disabled': disabled ? 'yes' : 'no',
    });
  }

  /// Edit hotspot user (password, profile, comment)
  Future<void> editHotspotUser(
    String id, {
    String? password,
    String? profile,
    String? comment,
    String? limitUptime,
    String? limitBytesTotal,
  }) async {
    await sendCommand('/ip/hotspot/user/set', params: {
      '.id': id,
      if (password != null && password.isNotEmpty) 'password': password,
      if (profile != null && profile.isNotEmpty) 'profile': profile,
      if (comment != null) 'comment': comment,
      if (limitUptime != null) 'limit-uptime': limitUptime,
      if (limitBytesTotal != null) 'limit-bytes-total': limitBytesTotal,
    });
  }

  /// List PPP secrets
  Future<MikroTikReply> getPPPSecrets() async {
    return sendCommand('/ppp/secret/print');
  }

  /// List active PPP connections
  Future<MikroTikReply> getPPPActive() async {
    return sendCommand('/ppp/active/print');
  }

  /// Add PPP secret
  Future<void> addPPPSecret({
    required String name,
    required String password,
    String profile = 'default',
    String service = 'pppoe',
    String comment = '',
  }) async {
    await sendCommand('/ppp/secret/add', params: {
      'name': name,
      'password': password,
      'profile': profile,
      'service': service,
      if (comment.isNotEmpty) 'comment': comment,
    });
  }

  /// Remove PPP secret
  Future<void> removePPPSecret(String id) async {
    await sendCommand('/ppp/secret/remove', params: {'.id': id});
  }

  /// Disconnect active PPP session
  Future<void> disconnectPPPActive(String id) async {
    await sendCommand('/ppp/active/remove', params: {'.id': id});
  }

  /// List IP addresses
  Future<MikroTikReply> getIpAddresses() async {
    return sendCommand('/ip/address/print');
  }

  /// List DHCP leases
  Future<MikroTikReply> getDhcpLeases() async {
    return sendCommand('/ip/dhcp-server/lease/print');
  }

  /// Reboot router
  Future<void> reboot() async {
    _writeSentence(['/system/reboot']);
  }

  /// Run ping (single)
  Future<Map<String, String>> ping(String address, {int count = 4}) async {
    return getFirstReply('/ping', params: {
      'address': address,
      'count': '$count',
    });
  }

  /// Enable interface
  Future<void> enableInterface(String id) async {
    await sendCommand('/interface/enable', params: {'.id': id});
  }

  /// Disable interface
  Future<void> disableInterface(String id) async {
    await sendCommand('/interface/disable', params: {'.id': id});
  }

  // ── Hotspot Profiles ──────────────────────────────────────────────────────

  /// List all hotspot user profiles
  Future<MikroTikReply> getHotspotProfiles() async {
    return sendCommand('/ip/hotspot/user/profile/print');
  }

  /// Add a hotspot user profile
  Future<void> addHotspotProfile({
    required String name,
    String rateLimit = '',
    String sessionTimeout = '',
    String sharedUsers = '1',
    String addressPool = '',
  }) async {
    final params = <String, String>{'name': name};
    if (rateLimit.isNotEmpty) params['rate-limit'] = rateLimit;
    if (sessionTimeout.isNotEmpty) params['session-timeout'] = sessionTimeout;
    if (sharedUsers.isNotEmpty) params['shared-users'] = sharedUsers;
    if (addressPool.isNotEmpty) params['address-pool'] = addressPool;
    await sendCommand('/ip/hotspot/user/profile/add', params: params);
  }

  /// Remove a hotspot user profile by id
  Future<void> removeHotspotProfile(String id) async {
    await sendCommand('/ip/hotspot/user/profile/remove', params: {'.id': id});
  }

  /// Edit an existing hotspot user profile
  Future<void> editHotspotProfile(
    String id, {
    String? rateLimit,
    String? sessionTimeout,
    String? sharedUsers,
  }) async {
    final params = <String, String>{'.id': id};
    if (rateLimit != null) params['rate-limit'] = rateLimit;
    if (sessionTimeout != null) params['session-timeout'] = sessionTimeout;
    if (sharedUsers != null) params['shared-users'] = sharedUsers;
    await sendCommand('/ip/hotspot/user/profile/set', params: params);
  }
}
