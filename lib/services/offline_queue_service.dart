import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// A single failed CalDAV request, queued for a later retry.
class QueuedRequest {
  final String id;
  final String method; // 'PUT' (save) or 'DELETE'
  final String url;
  final Map<String, String> headers;
  final String? body;

  QueuedRequest({
    required this.id,
    required this.method,
    required this.url,
    required this.headers,
    this.body,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'url': url,
    'headers': headers,
    'body': body,
  };

  factory QueuedRequest.fromJson(Map<String, dynamic> json) => QueuedRequest(
    id: json['id'],
    method: json['method'],
    url: json['url'],
    headers: Map<String, String>.from(json['headers']),
    body: json['body'],
  );
}

/// Persists CalDAV requests that failed to send (e.g. while offline)
/// and retries them once connectivity is back.
class OfflineQueueService {
  static const String _queueKey = 'caldav_offline_queue';

  /// Adds a failed request to the queue.
  static Future<void> enqueue(QueuedRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    List<QueuedRequest> queue = await getQueue();

    // Avoid duplicate queued requests for the same event.
    queue.removeWhere((r) => r.url == request.url);
    queue.add(request);

    await prefs.setString(_queueKey, jsonEncode(queue.map((r) => r.toJson()).toList()));
    debugPrint("Queued request while offline (queue size: ${queue.length})");
  }

  /// Reads the current queue.
  static Future<List<QueuedRequest>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_queueKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded.map((e) => QueuedRequest.fromJson(e)).toList();
  }

  /// Drains the queue, sending every request to the server.
  static Future<void> processQueue() async {
    final prefs = await SharedPreferences.getInstance();
    List<QueuedRequest> queue = await getQueue();

    if (queue.isEmpty) return;
    debugPrint("Processing offline queue (${queue.length} request(s))...");

    List<QueuedRequest> failedAgain = [];

    for (var req in queue) {
      try {
        http.Response response;
        if (req.method == 'PUT') {
          // Falls back to an empty body rather than crashing if body is null.
          response = await http.put(Uri.parse(req.url), headers: req.headers, body: utf8.encode(req.body ?? '')).timeout(const Duration(seconds: 10));
        } else {
          response = await http.delete(Uri.parse(req.url), headers: req.headers).timeout(const Duration(seconds: 10));
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint("Offline request sent successfully: ${req.url.split('/').last}");
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          // A 4xx (Not Found, Forbidden, ...) means the request is stale
          // or invalid - retrying won't help, so drop it for good.
          debugPrint("Discarding stale request - server returned ${response.statusCode} for ${req.url.split('/').last}");
        } else {
          // 5xx server error (e.g. server restart, maintenance) - worth retrying later.
          debugPrint("Server has a temporary issue (error ${response.statusCode}). Keeping in queue.");
          failedAgain.add(req);
        }
      } catch (e) {
        // Genuinely offline (timeout, no connection) - keep for the next attempt.
        debugPrint("Network error/offline. Request stays in the queue.");
        failedAgain.add(req);
      }
    }

    // Only the requests that failed again (5xx or offline) get persisted.
    await prefs.setString(_queueKey, jsonEncode(failedAgain.map((r) => r.toJson()).toList()));
    if (failedAgain.isEmpty) {
      debugPrint("Offline queue fully drained.");
    }
  }
}