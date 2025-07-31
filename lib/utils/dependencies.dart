import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../data/repositories/download.dart';
import '../data/repositories/resource.dart';
import '../data/services/api/oauth.dart';
import '../data/services/api/scraper.dart';
import '../data/services/api/webdav.dart';
import '../data/services/local/sqlite.dart';
import '../data/services/local/storage.dart';
import '../ui/dav_browser/model.dart';
import '../ui/web_browser/model.dart';
import '../ui/home/model.dart';
import '../ui/resource/model.dart';
import '../ui/dav_settings/model.dart';

List<SingleChildWidget> get providers {
  return [
    Provider(create: (context) => AudioPlayer()),
    Provider(create: (context) => WebScraper()),
    Provider(create: (context) => WebDavClient()),
    Provider(create: (context) => OAuthService()),
    Provider(create: (context) => DatabaseService()),
    Provider(create: (context) => StorageService()),
    Provider(
      create: (context) => ResourceRepository(
        scraper: context.read<WebScraper>(),
        player: context.read<AudioPlayer>(),
        dbs: context.read<DatabaseService>(),
        sts: context.read<StorageService>(),
        client: context.read<WebDavClient>(),
        oauth: context.read<OAuthService>(),
      )..load(),
    ),
    // resource downloader
    ChangeNotifierProvider(
      create: (context) => ResourceDownloader(
        dbs: context.read<DatabaseService>(),
        sts: context.read<StorageService>(),
        oauth: context.read<OAuthService>(),
      ),
    ),
    // home
    ChangeNotifierProvider(
      create: (context) =>
          HomeViewModel(resourceRepo: context.read<ResourceRepository>()),
    ),
    // resource
    ChangeNotifierProvider(
      create: (context) => ResourceViewModel(
        resourceRepo: context.read<ResourceRepository>(),
        resourceDnr: context.read<ResourceDownloader>(),
      ),
    ),
    // web browser
    ChangeNotifierProvider(
      create: (context) =>
          WebBrowserModel(resourceRepo: context.read<ResourceRepository>()),
    ),
    // dav server
    ChangeNotifierProvider(
      create: (context) => DavSettingsViewModel(
        resourceRepo: context.read<ResourceRepository>(),
      ),
    ),
    // dav browser
    ChangeNotifierProvider(
      create: (context) =>
          DavBrowserModel(resourceRepo: context.read<ResourceRepository>()),
    ),
  ];
}
