import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../data/repositories/download.dart';
import '../../data/repositories/resource.dart';
import '../../data/services/api/oauth.dart';
import '../../model/resource.dart';
import '../../utils/helpers.dart';

class ResourceViewModel extends ChangeNotifier {
  ResourceViewModel({
    required ResourceRepository resourceRepo,
    required ResourceDownloader resourceDnr,
  }) : _resourceRepo = resourceRepo,
       _resourceDnr = resourceDnr {
    _init();
  }

  final ResourceRepository _resourceRepo;
  final ResourceDownloader _resourceDnr;
  // ignore: unused_field
  final _logger = Logger('ResourceViewModel');

  StreamSubscription? _subCurrIdx, _subPlaying;
  ImageProvider _image = defaultThumbnailImage;
  Resource? _resource;
  bool _running = true;
  bool _dataLocal = false;
  String _error = '';

  ResourceDownloader get downloader => _resourceDnr;
  ImageProvider get image => _image;
  Resource? get resource => _resource;
  bool get running => _running;
  bool get dataLocal => _dataLocal;
  String get error => _error;

  //
  // Note current item index is the item index of the currently playing
  // which is different from the current index of player sequence.
  //
  int? _currentItemIndex;
  int? _bookmarkItemIndex;
  int? get currentItemIndex => _currentItemIndex;
  int? get bookmarkItemIndex => _bookmarkItemIndex;

  Future<void> _init() async {
    // subscribe to the currentIndex
    _subCurrIdx = _resourceRepo.player.currentIndexStream.listen((event) async {
      // change of currentIndex => update currentItemIndex
      await _updateCurrentItemIndex();
    });
    // subscribe to the playing stream
    _subPlaying = _resourceRepo.player.playingStream.listen((event) async {
      if (event) {
        // playing => update currentItemIndex
        await _updateCurrentItemIndex();
      } else {
        // paused => update bookmarkItemIndex
        await _updateBookmarkItemIndex();
      }
    });
  }

  Future<void> load(String? resourceId) async {
    _running = true;
    try {
      if (resourceId != null) {
        // read resource
        _resource = await _resourceRepo.readResource(resourceId);
        _logger.fine('resource: ${resource.toString()}');
        // initial bookmark item index
        _bookmarkItemIndex = _resource!.bookmark?.index;
        // initial current item index
        if (_resourceRepo.currentResourceId == resourceId) {
          _currentItemIndex = _resourceRepo.currentItemIndex;
        } else {
          _currentItemIndex = null;
        }
        _image =
            await _resourceRepo.getThumbnailImage(resourceId) ??
            defaultThumbnailImage;
        _dataLocal = _resource!.items.every(
          (e) => e.uri.startsWith('file:///'),
        );
        _error = '';
      }
    } on Exception catch (e) {
      _error = e.toString();
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subCurrIdx?.cancel();
    _subPlaying?.cancel();
    super.dispose();
  }

  Future deleteResource() async {
    try {
      if (_resource != null) {
        await _resourceRepo.deleteResource(_resource!.resourceId);
        _resource = null;
      }
    } on Exception catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future _updateBookmarkItemIndex() async {
    if (_resourceRepo.currentResourceId == _resource?.resourceId) {
      _bookmarkItemIndex = _resourceRepo.currentItemIndex;
      // _logger.fine('bookmarkItemIndex: $_bookmarkItemIndex');
      notifyListeners();
    }
  }

  Future _updateCurrentItemIndex() async {
    if (_resourceRepo.currentResourceId == _resource?.resourceId) {
      _currentItemIndex = _resourceRepo.currentItemIndex;
      // _logger.fine('currentItemIndex: $_currentItemIndex');
      notifyListeners();
    }
  }

  Future playItem(ResourceItem item) async {
    _logger.fine('item:$item');
    try {
      if (_resource != null) {
        if (item.type?.primaryType == 'audio') {
          await _resourceRepo.playAudio(
            _resource!.resourceId,
            index: item.index,
          );
        } else if (item.type?.primaryType == 'image') {}
        if (_resourceRepo.currentResourceId == _resource?.resourceId) {
          _currentItemIndex = _resourceRepo.currentItemIndex;
        }
      }
    } on OAuthException catch (e) {
      _logger.warning(e.toString());
      if (e.cause == OAuthExCause.refres) {
        if (e.statusCode == 400) {
          _logger.fine('refresh token failed');
          _error = 'signin required';
        }
      }
    } on Exception catch (e) {
      // _logger.severe(e.toString());
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> restartOAuth(BuildContext context) async {
    try {
      if (_resource?.serverId != null) {
        await _resourceRepo.oauthRequest(_resource!.serverId!, context);
      }
      _error = '';
    } on Exception catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<File?> getItemFile(ResourceItem item) async {
    File? file;
    final resourceId = _resource?.resourceId;
    final index = _resource?.items.indexWhere((e) => e == item);
    if (resourceId != null && index != null) {
      file = await _resourceRepo.getItemFile(resourceId, index);
      load(resourceId);
    }
    return file;
  }
}
