import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../data/repositories/resource.dart';
import '../../model/webdav.dart';

class DavSettingsViewModel extends ChangeNotifier {
  final ResourceRepository _resourceRepo;
  DavSettingsViewModel({required ResourceRepository resourceRepo})
    : _resourceRepo = resourceRepo;

  // ignore: unused_field
  final _logger = Logger('DavSettingsViewModel');

  late WebDavServer _server;
  bool _loading = true;
  String _error = "";

  WebDavServer get server => _server;
  String get error => _error;
  bool get loading => _loading;

  Future<void> load(int? serverId) async {
    _logger.fine('_load');
    _loading = true;
    try {
      _server = await _resourceRepo.getServer(serverId) ?? WebDavServer.empty();
      _error = "";
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String> deleteServer() async {
    try {
      if (_server.id != null) {
        if (await _resourceRepo.deleteServer(_server.id!) == 1) {
          return 'server deleted';
        }
      } else {
        return 'server has no id';
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return 'failed to delete server';
  }

  Future<String> updateServer(WebDavServer server) async {
    try {
      if (server.id != null) {
        if (await _resourceRepo.updateServer(server) == 1) {
          return 'server updated';
        }
      } else {
        if (await _resourceRepo.createServer(server) != 0) {
          return 'server created';
        }
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return 'update failed';
  }

  Future<String> deleteTokens() async {
    try {
      final srv = _server;
      if (srv.id != null) {
        srv.auth.accessToken = null;
        srv.auth.refreshToken = null;
        if (await _resourceRepo.updateServer(srv) == 1) {
          return 'token deleted';
        } else {
          return 'failed to delete token';
        }

        // final auth = _server.auth;
        // auth.accessToken = null;
        // auth.refreshToken = null;
        // if (await _resourceRepo.updateServer(server.id!, {
        //       "auth": jsonEncode(auth.toSqlite()),
        //     }) ==
        //     1) {
        //   return 'token deleleted';
        // }
      } else {
        return 'server has no id';
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return 'update failed';
  }
}
