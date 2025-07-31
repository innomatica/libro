import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import '../ui/dav_browser/model.dart';
import '../ui/dav_browser/view.dart';
import '../ui/oauth/view.dart';
import '../ui/web_browser/model.dart';
import '../ui/web_browser/view.dart';
import '../ui/home/model.dart';
import '../ui/home/view.dart';
import '../ui/resource/model.dart';
import '../ui/resource/view.dart';
import '../ui/dav_settings/model.dart';
import '../ui/dav_settings/view.dart';
// import './routes.dart';

final logger = Logger('Routing');

final router = GoRouter(
  initialLocation: "/",
  routes: [
    // home
    GoRoute(
      path: "/",
      builder: (context, state) {
        final model = context.read<HomeViewModel>();
        return HomeView(model: model..load());
      },
      routes: [
        // dav_browser
        GoRoute(
          path: "dav_browser",
          builder: (context, state) {
            // passing object as extra
            // https://stackoverflow.com/questions/74741283/go-router-pass-object-to-new-route/74813017#74813017
            final model = context.read<DavBrowserModel>();
            final params = state.uri.queryParameters;
            final serverId = int.tryParse(params["serverId"] ?? '');
            return DavBrowser(model: model..load(serverId));
          },
        ),
        // dav_server
        GoRoute(
          path: "dav_server",
          builder: (context, state) {
            final model = context.read<DavSettingsViewModel>();
            final params = state.uri.queryParameters;
            final serverId = int.tryParse(params["serverId"] ?? '');
            return DavSettingsView(model: model..load(serverId));
          },
        ),
        // resource
        GoRoute(
          path: "resources",
          builder: (context, state) {
            final model = context.read<ResourceViewModel>();
            // passing url as query parameter
            // https://stackoverflow.com/questions/72976031/flutter-go-router-how-to-pass-multiple-parameters-to-other-screen
            final params = state.uri.queryParameters;
            return ResourceView(model: model..load(params["resourceId"]));
            // model: model..load.execute(params["resourceId"]));
          },
        ),
        // web_browser
        GoRoute(
          path: "web_browser",
          builder: (context, state) {
            // passing url as query parameter
            // https://stackoverflow.com/questions/72976031/flutter-go-router-how-to-pass-multiple-parameters-to-other-screen
            final model = context.read<WebBrowserModel>();
            final params = state.uri.queryParameters;
            return WebBrowser(model: model, url: params['url']);
          },
        ),
        // oauth
        GoRoute(
          path: "oauth_consent",
          builder: (context, state) {
            final params = state.uri.queryParameters;
            return ConsentPage(
              url: params['url'] ?? '',
              redirectUri: params['redirectUri'] ?? '',
            );
          },
        ),
      ],
    ),
  ],
);
