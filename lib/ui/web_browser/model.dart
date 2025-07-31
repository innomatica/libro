import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../../data/repositories/resource.dart';

class WebBrowserModel extends ChangeNotifier {
  WebBrowserModel({
    required ResourceRepository resourceRepo,
  }) : _resourceRepo = resourceRepo;
  final ResourceRepository _resourceRepo;

  // ignore: unused_field
  final _logger = Logger('BrowseViewModel');
  String message = "";

  String getFilter(String url) {
    if (url.contains('archive.org')) {
      // internet archive
      return "window.document.querySelector('meta[property=\"mediatype\"][content=\"audio\"]') != null;";
    } else if (url.contains('librivox.org')) {
      // librivox
      return "window.document.getElementsByClassName('book-page').length > 0;";
    } else if (url.contains('legamus')) {
      // legamus
      return "window.document.querySelector('a[href*=\"listen.legamus.eu\"]') !== null;";
    }
    return "";
  }

  Future fetch(String? url) async {
    if (url != null) {
      try {
        await _resourceRepo.scrapWebPage(url);
        message = 'item added';
      } on Exception catch (e) {
        _logger.warning(e.toString());
        message = 'failed to add';
      } finally {
        notifyListeners();
      }
    }
  }
}
