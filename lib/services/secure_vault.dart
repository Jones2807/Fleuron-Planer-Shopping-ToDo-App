import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A single CalDAV workspace: connection details plus which optional
/// modules (to-dos, shopping) are enabled for it.
class CalDavAccount {
  final String id;
  final String name;
  final String url;
  final String username;
  final String password;
  final bool isReadOnly;   // Read-only .ics subscription rather than a full account.
  final bool syncTodos;    // Should this account load to-dos?
  final bool syncShopping; // Should this account load shopping-list items?
  final bool isActive;     // Master switch to hide the workspace entirely.

  CalDavAccount({
    required this.id,
    required this.name,
    required this.url,
    this.username = '',
    this.password = '',
    this.isReadOnly = false,
    this.syncTodos = false,
    this.syncShopping = false,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'username': username,
    'password': password,
    'isReadOnly': isReadOnly,
    'syncTodos': syncTodos,
    'syncShopping': syncShopping,
    'isActive': isActive,
  };

  factory CalDavAccount.fromJson(Map<String, dynamic> json) => CalDavAccount(
    id: json['id'],
    name: json['name'],
    url: json['url'],
    username: json['username'] ?? '',
    password: json['password'] ?? '',
    isReadOnly: json['isReadOnly'] ?? false,
    syncTodos: json['syncTodos'] ?? false,
    syncShopping: json['syncShopping'] ?? false,
    isActive: json['isActive'] ?? true,
  );
}

/// Manages the secure, encrypted storage of sensitive credentials
/// (CalDAV and Grocy servers) on the device.
class SecureVault {
  static const _storage = FlutterSecureStorage();

  // --- Multi-account storage ---

  /// Loads all stored workspaces, including a one-time automatic
  /// migration from the app's older single-account storage format.
  static Future<List<CalDavAccount>> getAllAccounts() async {
    String? jsonStr = await _storage.read(key: 'caldav_accounts_v2');

    if (jsonStr != null) {
      List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => CalDavAccount.fromJson(e)).toList();
    }

    // Migration: recover data from the old single-account keys, if present.
    String? oldUrl = await _storage.read(key: 'caldav_url');
    String? oldUser = await _storage.read(key: 'caldav_user');
    String? oldPass = await _storage.read(key: 'caldav_pass');

    if (oldUrl != null && oldUrl.isNotEmpty) {
      final migratedAccount = CalDavAccount(
        id: 'account_family_01',
        name: 'Familien-Kalender',
        url: oldUrl,
        username: oldUser ?? '',
        password: oldPass ?? '',
        syncTodos: true, // That used to be the default before multi-account support.
        syncShopping: true,
      );

      await saveAllAccounts([migratedAccount]);

      // Delete the old keys so this migration only ever runs once.
      await _storage.delete(key: 'caldav_url');
      await _storage.delete(key: 'caldav_user');
      await _storage.delete(key: 'caldav_pass');

      return [migratedAccount];
    }

    return [];
  }

  /// Securely stores the complete list of workspaces.
  static Future<void> saveAllAccounts(List<CalDavAccount> accounts) async {
    final jsonList = accounts.map((a) => a.toJson()).toList();
    await _storage.write(key: 'caldav_accounts_v2', value: jsonEncode(jsonList));
  }

  // --- Backward-compatible original functions ---

  /// Saves the credentials for the CalDAV server.
  static Future<void> saveCalDavCredentials(String url, String user, String pass) async {
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);

    var accounts = await getAllAccounts();

    if (accounts.isEmpty) {
      accounts.add(CalDavAccount(
          id: 'account_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Hauptkalender', url: url, username: user, password: pass,
          syncTodos: true, syncShopping: true
      ));
    } else {
      // Only overwrite the first (primary) workspace; the rest stay untouched.
      var first = accounts.first;
      accounts[0] = CalDavAccount(
          id: first.id, name: first.name, url: url, username: user, password: pass,
          isReadOnly: first.isReadOnly, syncTodos: first.syncTodos, syncShopping: first.syncShopping, isActive: first.isActive
      );
    }
    await saveAllAccounts(accounts);
  }

  /// Retrieves the stored CalDAV credentials (always returns the
  /// primary workspace).
  static Future<Map<String, String?>> getCalDavCredentials() async {
    final accounts = await getAllAccounts();
    final activeAccounts = accounts.where((a) => a.isActive && !a.isReadOnly).toList();

    if (activeAccounts.isNotEmpty) {
      return {
        'url': activeAccounts.first.url,
        'user': activeAccounts.first.username,
        'pass': activeAccounts.first.password,
      };
    }
    return {'url': null, 'user': null, 'pass': null};
  }

  /// Deletes every stored credential from secure storage.
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Saves the credentials for the Grocy instance.
  static Future<void> saveGrocyCredentials(String url, String apiKey) async {
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    await _storage.write(key: 'grocy_url', value: url);
    await _storage.write(key: 'grocy_api_key', value: apiKey);
  }

  /// Retrieves the stored Grocy credentials.
  static Future<Map<String, String?>> getGrocyCredentials() async {
    return {
      'url': await _storage.read(key: 'grocy_url'),
      'api_key': await _storage.read(key: 'grocy_api_key'),
    };
  }
}

/// Holds the CalDAV server configuration needed at runtime, in memory.
class CalDavConfig {
  static String serverUrl = "";
  static String username = "";
  static String password = "";

  /// Loads the configuration from [SecureVault]. Returns `true` if
  /// credentials were found.
  static Future<bool> loadFromVault() async {
    final creds = await SecureVault.getCalDavCredentials();
    if (creds['url'] != null && creds['user'] != null && creds['pass'] != null) {
      serverUrl = creds['url']!;
      username = creds['user']!;
      password = creds['pass']!;
      return true;
    }
    return false;
  }

  /// Whether all required CalDAV credentials are currently loaded.
  static bool get isConfigured => serverUrl.isNotEmpty && username.isNotEmpty && password.isNotEmpty;
}

/// Holds the Grocy API configuration needed at runtime, in memory.
class GrocyConfig {
  static String serverUrl = "";
  static String apiKey = "";

  /// Loads the configuration from [SecureVault]. Returns `true` if
  /// credentials were found.
  static Future<bool> loadFromVault() async {
    final creds = await SecureVault.getGrocyCredentials();
    if (creds['url'] != null && creds['api_key'] != null) {
      serverUrl = creds['url']!;
      apiKey = creds['api_key']!;
      return true;
    }
    return false;
  }

  /// Whether all required Grocy credentials are currently loaded.
  static bool get isConfigured => serverUrl.isNotEmpty && apiKey.isNotEmpty;
}