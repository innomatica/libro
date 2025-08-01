import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../data/repositories/resource.dart';
import '../../model/resource.dart';
import '../../model/webdav.dart';
import '../../utils/helpers.dart';

class LibroItem {
  LibroItem({required this.res, required this.img});
  Resource res;
  ImageProvider img;
}

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required ResourceRepository resourceRepo})
    : _resourceRepo = resourceRepo {
    _init();
  }

  final ResourceRepository _resourceRepo;
  // ignore: unused_field
  final _logger = Logger('HomeViewModel');

  final List<WebDavServer> _servers = [];
  final List<LibroItem> _items = [];
  bool _running = true;
  String _error = "";
  String? _selectedResourceId;
  StreamSubscription? _subPlaying;

  List<LibroItem> get items => _items;
  List<WebDavServer> get servers => _servers;
  bool get running => _running;
  String get error => _error;
  // String? get selectedResourceId => _resourceRepo.currentResourceId;
  String? get selectedResourceId => _selectedResourceId;

  Future<ImageProvider> getThumbnailImage(String resourceId) async =>
      await _resourceRepo.getThumbnailImage(resourceId) ??
      defaultThumbnailImage;

  @override
  void dispose() {
    _subPlaying?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _subPlaying = _resourceRepo.player.playingStream.listen((event) {
      if (event) {
        // update selected resource id whenver the player
        // was started or stopped
        _selectedResourceId = _resourceRepo.currentResourceId;
        _logger.fine('event:$event - $_selectedResourceId');
        notifyListeners();
      }
    });
  }

  Future<void> load() async {
    // _logger.fine('_load');
    _running = true;
    try {
      final resources = await _resourceRepo.getResources();
      _items.clear();
      for (final resource in resources) {
        _items.add(
          LibroItem(
            res: resource,
            img:
                await _resourceRepo.getThumbnailImage(resource.resourceId) ??
                defaultThumbnailImage,
          ),
        );
      }
      // _logger.fine('items:$_items');
      _servers.clear();
      _servers.addAll(await _resourceRepo.getServers());
      // _logger.fine('servers:$_server');
    } on Exception catch (e) {
      _logger.severe(e.toString());
      _error = e.toString();
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future play(String resourceId) async {
    await _resourceRepo.playAudio(resourceId);
    // notifyListeners();
  }
}
