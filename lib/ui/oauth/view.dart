import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key, required this.url, required this.redirectUri});
  final String url;
  final String redirectUri;

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  late final WebViewController controller;
  // ignore: unused_field
  final _logger = Logger("ConstentPage");

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onNavigationRequest: (request) async {
          // _logger.fine('onNavigationRequest.url:${request.url}');
          if (request.url.contains(widget.redirectUri)) {
            final params = Uri.parse(request.url).queryParameters;
            // _logger.fine('auth params: $params');
            Navigator.of(context).pop(params);
            // return NavigationDecision.navigate;
          }
          return NavigationDecision.navigate;
          // return NavigationDecision.prevent;
        }),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios),
            onPressed: () => context.pop(),
          ),
          title: Text('Consent Page'),
        ),
        body: WebViewWidget(controller: controller));
  }
}
