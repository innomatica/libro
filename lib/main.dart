import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'utils/constants.dart';
import 'utils/routing.dart';
import 'utils/dependencies.dart';

void main() async {
  // set logger level and format
  if (kDebugMode) Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    debugPrint(
      '\u001b[1;33m ${record.loggerName}(${record.level.name}): ${record.time}: ${record.message}\u001b[0m',
    );
  });

  // audio backround
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  // necesssary for successful initialization of AudioPlayer
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MultiProvider(providers: providers, child: const MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: appName,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.limeAccent,
          brightness: Brightness.dark,
        ),
        // https://api.flutter.dev/flutter/material/PageTransitionsTheme-class.html
        // pageTransitionsTheme: const PageTransitionsTheme(
        //   builders: <TargetPlatform, PageTransitionsBuilder>{
        //     TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        //     TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),
        //     TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        //   },
        // ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
