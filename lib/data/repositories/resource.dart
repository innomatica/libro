import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:logging/logging.dart';

import '../../model/resource.dart';
import '../../model/webdav.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../services/api/oauth.dart';
import '../services/api/scraper.dart';
import '../services/api/webdav.dart';
import '../services/local/sqlite.dart';
import '../services/local/storage.dart';

enum ResourceRepoExCause { params }

class ResourceRepoException implements Exception {
  ResourceRepoException(this.cause, {this.details});
  ResourceRepoExCause cause;
  String? details;

  @override
  String toString() => '${cause.name}:$details';
}

class ResourceRepository {
  ResourceRepository({
    required WebScraper scraper,
    required AudioPlayer player,
    required DatabaseService dbs,
    required StorageService sts,
    required WebDavClient client,
    required OAuthService oauth,
  }) : _scraper = scraper,
       _player = player,
       _dbs = dbs,
       _sts = sts,
       _client = client,
       _oauth = oauth {
    _init();
  }

  final WebScraper _scraper;
  final AudioPlayer _player;
  final DatabaseService _dbs;
  final StorageService _sts;
  final WebDavClient _client;
  final OAuthService _oauth;

  StreamSubscription? _subPlaying;
  static const refreshLimit = 600;
  // ignore: unused_field
  final _logger = Logger('ResourceRepository');

  AudioPlayer get player => _player;

  // Note currentItemIndex is the unique index of the resource item
  // which is different from the currentIndex of the player sequence.
  // currentItemIndex is stored in the extras field of the tag.
  int? get currentItemIndex => _player.currentIndex != null
      ? _player.sequence[_player.currentIndex!].tag.extras["index"]
      : null;
  String? get currentResourceId => _player.currentIndex != null
      ? _player.sequence[_player.currentIndex!].tag.extras["resourceId"]
      : null;

  Future _init() async {
    // update bookmark when playing == false i.e., when
    // the player was explicitly paused
    _subPlaying = _player.playingStream.listen((event) async {
      if (event == false) {
        // paused => update bookmark
        await _updateBookmark();
      }
    });
  }

  void dispose() {
    _subPlaying?.cancel();
  }

  Future<List<Resource>> getResources() async {
    try {
      final res = await _dbs.queryAll("SELECT * from resources");
      return res.map((e) => Resource.fromSqlite(e)).toList();
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<int> createResource(Resource resource) async {
    try {
      final data = resource.toSqlite();
      final args = List.filled(data.length, '?').join(',');
      return await _dbs.insert(
        "INSERT OR REPLACE INTO resources(${data.keys.join(',')}) VALUES($args)",
        data.values.toList(),
      );
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<Resource?> readResource(String resourceId) async {
    try {
      final res = await _dbs.query(
        "SELECT resources.*, servers.auth from resources LEFT JOIN servers "
        "ON resources.server_id = servers.id WHERE resource_id = ?",
        [resourceId],
      );
      return res != null ? Resource.fromSqlite(res) : null;
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<int> updateResource(
    String resourceId,
    Map<String, Object?> data,
  ) async {
    try {
      // do anything related to storage
      final sets = data.keys.map((e) => '$e = ?').join(',');
      return _dbs.update("UPDATE resources SET $sets WHERE resource_id = ?", [
        ...data.values,
        resourceId,
      ]);
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<int> deleteResource(String resourceId) async {
    try {
      if (currentResourceId == resourceId) {
        await _player.stop();
        // version 0.10 specific
        await _player.clearAudioSources();
      }
      await _sts.deleteDirectory(resourceId);
      return await _dbs.delete('DELETE FROM resources WHERE resource_id = ?', [
        resourceId,
      ]);
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<void> scrapWebPage(String url) async {
    try {
      final result = await _scraper.scrap(url);
      await createResource(result);
    } on Exception catch (e) {
      _logger.severe('scrapWebpage: $e');
      rethrow;
    }
  }

  Future<void> _saveAssetImagetoFile(
    String assetPath,
    String resourceId,
    String fname,
  ) async {
    final byteData = await rootBundle.load('assets/$assetPath');
    final file = await _sts.createFile(resourceId, fname);
    await file.writeAsBytes(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );
  }

  Future<ImageProvider?> getThumbnailImage(String resourceId) async {
    try {
      final resource = await readResource(resourceId);
      if (resource?.thumbnail?.startsWith('file') == true) {
        // image stored locally
        final file = File.fromUri(Uri.parse(resource!.thumbnail!));
        // return file image
        return FileImage(file);
      } else if (resource?.thumbnail?.startsWith('http') == true) {
        _logger.fine('network image: ${resource!.thumbnail}');
        // on the network => download
        final res = await http.get(
          Uri.parse(resource.thumbnail!),
          headers: await _getAuthHeaders(resource.auth, resource.serverId),
        );
        if (res.statusCode == 200) {
          _logger.fine('image downloaded');
          // download image
          final file = await _sts.getFile(
            resourceId,
            resource.thumbnail!.split('/').last,
          );
          // you may have to create directory as well
          await file.create(recursive: true);
          await file.writeAsBytes(res.bodyBytes);
          _logger.fine('file written');
          // update database
          await updateResource(resourceId, {
            "thumbnail": Uri.file(file.path).toString(),
          });
          // return file image
          return FileImage(file);
        } else {
          // download failed => handle below
          resource.thumbnail = null;
        }
      }

      if (resource?.thumbnail == null) {
        // no thumbnail => provide asset image
        await _saveAssetImagetoFile(
          defaultThumbnailPath,
          resourceId,
          defaultThumbnailFname,
        );
        final file = await _sts.getFile(resourceId, defaultThumbnailFname);
        // update database
        final uri = Uri.file(file.path);
        await updateResource(resourceId, {"thumbnail": uri.toString()});
        return FileImage(file);
      } else {
        // unknown uri => this should not happen
        return defaultThumbnailImage;
      }
    } on Exception catch (e) {
      _logger.severe('getThumbnailImage: $e');
      rethrow;
    }
  }

  Future<File?> getItemFile(String resourceId, int index) async {
    try {
      final resource = await readResource(resourceId);
      _logger.fine('resourceId: $resourceId, index: $index');
      final uri = Uri.tryParse(resource?.items[index].uri ?? '');
      if (uri?.scheme == 'http' || uri?.scheme == 'https') {
        // download data
        // _logger.fine('downloading data: ${uri.toString()}');
        final res = await http.get(
          uri!,
          headers: await _getAuthHeaders(resource!.auth, resource.serverId),
        );
        if (res.statusCode == 200) {
          final file = await _sts.getFile(resourceId, uri.path.split('/').last);
          await file.create(recursive: true);
          await file.writeAsBytes(res.bodyBytes);
          // _logger.fine('data downloaded');
          resource.items[index].uri = Uri.file(file.path).toString();
          // update resource
          await updateResource(resourceId, {
            "items": jsonEncode(resource.items.map((e) => e.toMap()).toList()),
          });
          return file;
        }
        // update resource
      } else if (uri?.scheme == 'file') {
        return File.fromUri(uri!);
      }
    } on Exception catch (e) {
      _logger.severe(e.toString());
    }
    return null;
  }

  Future<void> _updateBookmark() async {
    if (currentResourceId != null && currentItemIndex != null) {
      _logger.fine(
        '_updateBookmark: $currentItemIndex, ${_player.position.inSeconds}',
      );
      // update bookmark
      final bookmark = Bookmark(
        index: currentItemIndex!,
        position: _player.position.inSeconds,
      );
      final bmdata = {'bookmark': jsonEncode(bookmark.toMap())};
      await updateResource(currentResourceId!, bmdata);
    }
  }

  Future<void> playAudio(String resourceId, {int? index}) async {
    if (resourceId == currentResourceId) {
      // same resource
      if (index == currentItemIndex || index == null) {
        if (_player.playing) {
          _logger.fine('pause');
          await _player.pause();
        } else {
          _logger.fine('resume');
          await _player.play();
        }
      } else {
        _logger.fine('seek');
        await _player.seek(Duration(seconds: 0), index: index);
        await _player.play();
      }
      return;
    } else {
      // new resource
      _logger.fine('change source');
      // clear existing sequence
      await _player.stop();
      try {
        // read the new resource
        final resource = await readResource(resourceId);
        // FIXME: raise exception or something
        if (resource == null) return;
        // int initialIndex = 0;
        final sources = <IndexedAudioSource>[];

        // int sourceIdx = 0;
        // final headers = await _getAuthHeaders(
        //   resource.auth,
        //   resource.serverId,
        //   forceRefresh: true,
        // );

        for (final item in resource.items) {
          if (item.type?.primaryType != 'audio') continue;
          if (item.uri.startsWith('file')) {
            // file source
            sources.add(
              AudioSource.file(
                // file.path,
                Uri.decodeFull(item.uri).split('file://').last,
                tag: MediaItem(
                  id: '${resource.resourceId}-${item.title}',
                  album: resource.title,
                  title: item.title,
                  artUri: await _sts.getUri(
                    resourceId,
                    resource.thumbnail!.split('/').last,
                  ),
                  extras: {
                    'resourceId': resource.resourceId,
                    'index': item.index,
                  },
                ),
              ),
            );
          } else {
            // network source
            sources.add(
              AudioSource.uri(
                Uri.parse(item.uri),
                tag: MediaItem(
                  id: '${resource.resourceId}-${item.index}',
                  album: resource.title,
                  title: item.title,
                  artUri: await _sts.getUri(
                    resourceId,
                    resource.thumbnail!.split('/').last,
                  ),
                  extras: {
                    'resourceId': resource.resourceId,
                    'index': item.index,
                  },
                ),
                headers: await _getAuthHeaders(
                  resource.auth,
                  resource.serverId,
                  forceRefresh: true,
                ),
              ),
            );
            // in case of network audio with limited token life span, play
            // only one item to avoid potential error from expired token
            if (resource.auth?.method == AuthMethod.nubis) break;
          }
        }
        // _logger.fine('sources:$sources');

        // apply bookmark if index was not given
        final idx = index ?? resource.bookmark?.index ?? 0;
        final pos = idx == resource.bookmark?.index
            ? resource.bookmark?.position ?? 0
            : 0;
        await _player.setAudioSources(
          sources,
          initialIndex: idx,
          initialPosition: Duration(seconds: pos),
        );
        await _player.play();
        return;
      } on Exception catch (e) {
        _logger.severe('playAudio: $e');
        rethrow;
      }
    }
  }

  Future<Map<String, String>?> _getAuthHeaders(
    WebDavAuth? auth,
    int? serverId, {
    bool forceRefresh = false,
  }) async {
    if (auth == null || auth.method == AuthMethod.none) {
      // no auth
      return null;
    } else if (auth.method == AuthMethod.basic) {
      // basic auth
      final credential = base64Encode(
        utf8.encode('${auth.username}:${auth.password}'),
      );
      return {'Authorization': 'Basic $credential'};
    } else if (auth.method == AuthMethod.nubis && serverId != null) {
      // oauth => refresh token
      try {
        final newAuth = await oauthRefresh(serverId, force: forceRefresh);
        return {'Authorization': 'Bearer ${newAuth.accessToken}'};
      } on Exception catch (e) {
        _logger.severe(e.toString());
        rethrow;
      }
    }
    throw ResourceRepoException(
      ResourceRepoExCause.params,
      details: "invalid parameters: auth:$auth, serverId:$serverId",
    );
  }

  //-------------------WebDavServer-----------------------------

  Future<List<WebDavServer>> getServers() async {
    try {
      final rows = await _dbs.queryAll("SELECT * FROM servers");
      return rows.map((e) => WebDavServer.fromSqlite(e)).toList();
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<WebDavServer?> getServer(int? serverId) async {
    try {
      final rows = await _dbs.queryAll(
        "SELECT * FROM servers WHERE id=$serverId",
      );
      return rows.isNotEmpty ? WebDavServer.fromSqlite(rows.first) : null;
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<int> createServer(WebDavServer server) async {
    try {
      final data = server.toSqlite();
      final args = List.generate(data.length, (i) => "?").join(",");
      final keys = data.keys.join(',');
      return await _dbs.insert(
        "INSERT INTO servers($keys) VALUES($args)",
        data.values.toList(),
      );
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<WebDavServer?> readServer(int serverId) async {
    try {
      final row = await _dbs.query("SELECT * FROM servers WHERE id = ?", [
        serverId,
      ]);
      return row != null ? WebDavServer.fromSqlite(row) : null;
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<int> updateServer(WebDavServer server) async {
    try {
      final data = server.toSqlite();
      final serverId = data.remove('id');
      if (serverId != null) {
        final sets = data.keys.map((e) => '$e = ?').join(',');
        return await _dbs.update("UPDATE servers SET $sets WHERE id = ?", [
          ...data.values,
          serverId,
        ]);
      }
      return -1;
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<int> deleteServer(int serverId) async {
    try {
      return await _dbs.delete('DELETE FROM servers WHERE id = ?', [serverId]);
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<List<WebDavItem>> getDavItems(int? serverId, String path) async {
    if (serverId != null) {
      try {
        final server = await readServer(serverId);
        final headers = await _getAuthHeaders(server?.auth, server?.id);
        return _client.propFind(url: '${server?.url}$path', headers: headers);
      } on Exception catch (e) {
        _logger.severe(e.toString());
        rethrow;
      }
    }
    throw ResourceRepoException(
      ResourceRepoExCause.params,
      details: "parameter missing: serverId:$serverId",
    );
  }

  Future<WebDavServer> oauthRequest(int serverId, BuildContext context) async {
    try {
      final server = await readServer(serverId);
      if (server == null) {
        throw ResourceRepoException(
          ResourceRepoExCause.params,
          details: "server not found",
        );
      }
      // _logger.fine('server:$server');
      if (server.extra == null) {
        throw ResourceRepoException(
          ResourceRepoExCause.params,
          details: "parameter missing: server.extra:${server.extra}",
        );
      }
      // Pushed Authorization Request
      final par = await _oauth.pushedAuthRequest(server.auth);
      //
      // Authorization Code Grant using WebView
      //
      // https://datatracker.ietf.org/doc/html/rfc6749#section-4.1.1
      // Through PAR scheme
      // https://datatracker.ietf.org/doc/html/rfc9126#name-authorization-request
      //
      var authCode = "";
      if (context.mounted) {
        final authEp = server.auth.extra!["authEp"];
        final clientId = server.auth.username;
        final scope = server.auth.scope;
        final audience = server.auth.audience;
        final redirectUri = server.auth.redirectUri;
        // launch webview with par.requrest_uri
        final codeGrantResp = await context.push(
          Uri(
            path: "/oauth_consent",
            queryParameters: {
              'url': Uri.parse(authEp)
                  .replace(
                    queryParameters: {
                      "response_type": "code",
                      "client_id": clientId,
                      "scope": scope,
                      "audience": audience,
                      "request_uri": par.requestUri,
                      "state": par.nonce,
                    },
                  )
                  .toString(),
              'redirectUri': redirectUri,
            },
          ).toString(),
        );
        // https://datatracker.ietf.org/doc/html/rfc6749#section-4.1.2
        // {
        //   code: authelia_ac_keKr7gDzy9It...
        //   iss: https://nacauth.innomatic.ca,
        //   scope: offline_access authelia.bearer.authz,
        //   state: M6bv0OaDSZleIvzHFhu...
        // }
        // _logger.fine('auth code grant: $codeGrantResp');
        if (codeGrantResp is! Map || !codeGrantResp.containsKey("code")) {
          throw Exception('auth code grant failed:$codeGrantResp');
        }
        authCode = codeGrantResp["code"];
      } else {
        throw ResourceRepoException(
          ResourceRepoExCause.params,
          details: "context not mounted",
        );
      }
      // exchange token
      final tokenData = await _oauth.exchangeToken(
        auth: server.auth,
        code: authCode,
        pkce: par.pkce,
      );
      // final auth = server.auth;
      // auth.accessToken = tokenData.accessToken;
      server.auth.accessToken = tokenData.accessToken;
      // if (tokenData.refreshToken is String) {
      //   auth.refreshToken = tokenData.refreshToken;
      // }
      if (tokenData.refreshToken != null) {
        server.auth.refreshToken = tokenData.refreshToken;
      }
      // if (tokenData.expiresIn is int) {
      //   auth.expiresAt =
      //       tokenData.expiresIn! +
      //       DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // }
      if (tokenData.expiresIn != null) {
        server.auth.expiresAt =
            tokenData.expiresIn! +
            DateTime.now().microsecondsSinceEpoch ~/ 1000;
      }
      // update server
      // await updateServer(serverId, {"auth": jsonEncode(auth.toSqlite())});
      await updateServer(server);
      final updated = await readServer(serverId);
      if (updated == null) {
        throw ResourceRepoException(
          ResourceRepoExCause.params,
          details: "failed to update server",
        );
      }
      return updated;
      // } on OAuthException catch (e) {
      //   _logger.severe(e.toString());
      //   rethrow;
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }

  Future<WebDavAuth> oauthRefresh(int serverId, {bool force = false}) async {
    try {
      final server = await readServer(serverId);
      if (server == null) {
        throw ResourceRepoException(
          ResourceRepoExCause.params,
          details: "server not found",
        );
      }
      // check the life time of the access token if exists
      if (!force) {
        final nowInSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (server.auth.accessToken != null &&
            server.auth.expiresAt != null &&
            (server.auth.expiresAt! - nowInSec) > refreshLimit) {
          // no need to update
          _logger.fine('access token is healthy');
          return server.auth;
        }
      }

      // refresh required
      final tokenData = await _oauth.refreshToken(server.auth);
      // update oauth data
      // final auth = server.auth;
      // auth.accessToken = tokenData.accessToken;
      server.auth.accessToken = tokenData.accessToken;
      // if (tokenData.refreshToken != null) {
      //   auth.refreshToken = tokenData.refreshToken;
      // }
      if (tokenData.refreshToken != null) {
        server.auth.refreshToken = tokenData.refreshToken;
      }
      // if (tokenData.expiresIn != null) {
      //   auth.expiresAt =
      //       tokenData.expiresIn! +
      //       DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // }
      if (tokenData.expiresIn != null) {
        server.auth.expiresAt =
            tokenData.expiresIn! +
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
      }

      // await updateServer(serverId, {"auth": jsonEncode(auth.toSqlite())});
      await updateServer(server);
      // return auth;
      return server.auth;
      // } on OAuthException catch (e) {
      //   _logger.severe(e.toString());
      //   rethrow;
    } on Exception catch (e) {
      _logger.severe(e.toString());
      rethrow;
    }
  }
}
