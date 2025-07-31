import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../model/resource.dart';
import '../../model/webdav.dart';
import '../services/api/oauth.dart';
import '../services/local/sqlite.dart';
import '../services/local/storage.dart';

class ResourceDownloader extends ChangeNotifier {
  ResourceDownloader({
    required DatabaseService dbs,
    required StorageService sts,
    required OAuthService oauth,
  }) : _dbs = dbs,
       _sts = sts,
       _oauth = oauth;

  late final DatabaseService _dbs;
  late final StorageService _sts;
  late final OAuthService _oauth;
  final _logger = Logger('ResourceDownloader');

  bool _running = false;
  bool _completed = false;
  String _error = "";
  double? _result;
  String? _resourceId;
  bool _cancel = false;

  bool get running => _running;
  bool get completed => _completed;
  String get error => _error;
  double? get result => _result;
  String? get resourceId => _resourceId;
  void cancel() => _cancel = true;

  void clearResult({bool notify = false}) {
    _result = null;
    _cancel = false;
    _error = "";
    _running = false;
    _resourceId = null;
    _completed = false;
    if (notify) notifyListeners();
  }

  Future<void> run(String? resourceId) async {
    // allow only one running instance
    if (_running) return;
    // resourceId is actually required
    if (resourceId == null) return;
    // start process
    clearResult();
    _running = true;
    _resourceId = resourceId;
    notifyListeners();

    final client = http.Client();
    try {
      // read resource
      final row = await _dbs.query(
        "SELECT resources.*, servers.auth "
        "FROM resources LEFT JOIN servers "
        "ON resources.server_id = servers.id "
        "WHERE resource_id = ?",
        [resourceId],
      );
      if (row == null) return;

      final resource = Resource.fromSqlite(row);
      final total = resource.items.length;
      final headers = await _getAuthHeaders(resource);
      // _logger.fine('resource:$resource');
      int idx = 0;
      for (final item in resource.items) {
        // _logger.fine(
        //     'item:${item.title}, ${item.uri}, $idx, $total, ${idx / total}');
        _result = idx / total;
        notifyListeners();
        if (item.uri.startsWith('http')) {
          // download file
          final req = http.Request('GET', Uri.parse(item.uri));
          if (headers != null) req.headers.addAll(headers);
          final res = await client.send(req);
          // _logger.fine('statusCode: ${res.statusCode}');
          if (res.statusCode == 200) {
            final fname = Uri.decodeFull(item.uri).split('/').last;
            final file = await _sts.getFile(resourceId, fname);
            await file.create(recursive: true);
            final sink = file.openWrite();
            await res.stream.pipe(sink);
            // replace the item uri
            item.uri = Uri.file(file.path).toString();
            // _logger.fine('item.uri: ${item.uri}');
          }
        }
        // update record
        await _dbs.update(
          "UPDATE resources SET items = ? WHERE resource_id = ?",
          [
            jsonEncode(resource.items.map((e) => e.toMap()).toList()),
            resourceId,
          ],
        );
        if (_cancel) {
          // _logger.fine('download canceled');
          break;
        }
        idx = idx + 1;
      }
    } on OAuthException catch (e) {
      _logger.severe(e.toString());
      // _error = 'authentication error: ${e.cause.name}';
    } on Exception catch (e) {
      _logger.severe(e.toString());
      _error = e.toString();
    } finally {
      client.close();
      _running = false;
      _completed = true;
      // _logger.fine('download completed');
      notifyListeners();
    }
  }

  Future<Map<String, String>?> _getAuthHeaders(Resource resource) async {
    final auth = resource.auth;
    if (auth?.method == AuthMethod.basic) {
      final credential = base64Encode(
        utf8.encode('${auth?.username}:${auth?.password}'),
      );
      return {'Authorization': 'Basic $credential'};
    } else if (auth?.method == AuthMethod.nubis) {
      try {
        final tokenData = await _oauth.refreshToken(auth!);
        auth.accessToken = tokenData.accessToken;
        if (tokenData.refreshToken != null) {
          auth.refreshToken = tokenData.refreshToken;
        }
        if (tokenData.expiresIn != null) {
          auth.expiresAt =
              tokenData.expiresIn! +
              DateTime.now().millisecondsSinceEpoch ~/ 1000;
        }
        await _dbs.update("UPDATE servers SET auth = ? WHERE id= ?", [
          jsonEncode(auth.toMap()),
          resource.serverId,
        ]);
        return {'Authorization': 'Bearer ${tokenData.accessToken}'};
      } on OAuthException catch (e) {
        _logger.severe(e.toString());
        rethrow;
      } on Exception catch (e) {
        _logger.severe(e.toString());
        rethrow;
      }
    }
    return null;
  }
}
