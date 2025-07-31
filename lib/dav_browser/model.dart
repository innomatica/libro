import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/resource.dart';
import '../../data/services/api/oauth.dart';
import '../../data/services/api/webdav.dart';
import '../../model/resource.dart';
import '../../model/webdav.dart';
import '../../utils/helpers.dart';

class DavBrowserModel extends ChangeNotifier {
  DavBrowserModel({required ResourceRepository resourceRepo})
    : _resourceRepo = resourceRepo;

  final ResourceRepository _resourceRepo;
  // ignore: unused_field
  final _logger = Logger('DavBrowserModel');
  final _uuid = Uuid();

  WebDavServer? _server;
  List<WebDavItem> _davItems = [];
  String _currentPath = '';
  bool _running = true;
  String _error = '';
  bool _hasMediaItems = false;

  WebDavServer? get server => _server;
  List<WebDavItem> get davItems => _davItems;
  String get currentPath => _currentPath;
  bool get hasMediaItems => _hasMediaItems;
  bool get running => _running;
  String get error => _error;

  Future<void> load(int? serverId) async {
    _logger.fine('load: $serverId');
    _running = true;
    try {
      if (serverId != null) {
        _server = await _resourceRepo.readServer(serverId);
        // _logger.fine('server:$server');
        // check token
        if (_server!.auth.method == AuthMethod.nubis &&
            _server!.auth.accessToken == null) {
          _error = "signin required";
        } else {
          await setPath(_server!.root);
        }
      } else {
        _error = 'database error: server not found';
      }
    } on Exception catch (e) {
      _error = e.toString();
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> startOAuth(BuildContext context) async {
    _logger.fine('start oauth process');
    _error = "loading";
    notifyListeners();
    try {
      _server = await _resourceRepo.oauthRequest(_server!.id!, context);
      await setPath(_server!.root);
    } on OAuthException catch (e) {
      _error = e.toString();
    } on Exception catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> setPath(String path) async {
    _logger.fine('setPath: $path');
    _running = true;
    try {
      if (_server != null) {
        _currentPath = path;
        // get dav itmes from the server
        _davItems = await _resourceRepo.getDavItems(_server!.id, path);
        _logger.fine('davItems:$_davItems');
        // check if any media items found
        _hasMediaItems = false;
        for (final davItem in _davItems) {
          if (supportedContentTypes.contains(
            davItem.contentType?.primaryType,
          )) {
            _hasMediaItems = true;
            break;
          }
        }
        _error = '';
      } else {
        _error = 'database error: server not found';
      }
    } on OAuthException catch (e) {
      if (e.cause == OAuthExCause.refres && e.statusCode == 400) {
        _error = "signin required";
      }
    } on WebDavClientException catch (e) {
      if (e.cause == WebDavExCause.http && e.statusCode == 401) {
        _error = "Unauthorized Access\nClear Token and Retry";
      }
      if (e.cause == WebDavExCause.http && e.statusCode == 404) {
        _error = "Page Not Found\nCheck Server URL";
      }
    } on Exception catch (e) {
      _error = e.toString();
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  //
  // Add new resource from the DAV server
  //
  Future<bool> addToResources() async {
    _running = true;
    try {
      // build Resource from _items
      final resource = _resourceFromDavItems();
      if (resource != null) {
        // add it to the collection
        final res = await _resourceRepo.createResource(resource);
        return res > 1;
      }
      return false;
    } on Exception catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Resource? _resourceFromDavItems() {
    if (_davItems.isEmpty) return null;

    final path = currentPath.split('/').reversed;
    // path must be like /category?/genre?/author/title
    if (path.length < 2) return null;

    String title = path.elementAt(0);
    String author = path.elementAt(1);
    String genre = path.length > 2 ? path.elementAt(2) : 'Unknown';
    String category = path.length > 3 ? path.elementAt(3) : 'Unknown';
    List<ResourceItem> resourceItems = [];

    String? thumbnail;
    String urlPrefix = '${_server?.url}$currentPath';
    // _logger.fine('urlPrefix: $urlPrefix');

    int index = 0;
    List<ContentType> mediaTypes = [];
    for (final davItem in _davItems) {
      final fname = davItem.href.split('/').last;
      if (supportedContentTypes.contains(davItem.contentType?.primaryType)) {
        resourceItems.add(
          ResourceItem(
            index: index,
            title: fname.split('.')[0],
            // uri has to be encoded
            uri: Uri.encodeFull('$urlPrefix/$fname'),
            size: davItem.contentLength,
            type: davItem.contentType,
          ),
        );
        // update media item
        if (!mediaTypes.contains(davItem.contentType)) {
          mediaTypes.add(davItem.contentType!);
        }
        // update thumbnail
        if (fname.toLowerCase().contains('cover')) {
          thumbnail = Uri.encodeFull('$urlPrefix/$fname');
        }
        index++;
      }
    }
    // resource must have non empty items
    if (resourceItems.isEmpty) {
      return null;
    } else {
      return Resource(
        resourceId: _uuid.v5(Namespace.url.value, urlPrefix),
        category: category,
        genre: genre,
        title: title,
        author: author,
        thumbnail: thumbnail,
        items: resourceItems,
        mediaTypes: mediaTypes,
        serverId: _server?.id,
        extra: {'source': _server?.title, 'url': Uri.encodeFull(urlPrefix)},
      );
    }
  }
}
