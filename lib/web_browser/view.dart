import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:webview_flutter/webview_flutter.dart';

import './model.dart';

const defaultUrl = 'https://duckduck.go';

class WebBrowser extends StatefulWidget {
  const WebBrowser({super.key, required this.model, required String? url})
    : url = url ?? defaultUrl;
  final WebBrowserModel model;
  final String url;

  @override
  State<WebBrowser> createState() => _WebBrowserState();
}

class _WebBrowserState extends State<WebBrowser> {
  final _controller = WebViewController();
  bool _showFab = false;
  // ignore: unused_field
  final _logger = Logger('BrowserViewState');

  @override
  void initState() {
    super.initState();
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // NOTE: there is a serious bug reported regarding this:
            // https://github.com/flutter/flutter/issues/80328
            final found = await _controller.runJavaScriptReturningResult(
              widget.model.getFilter(url),
            );
            if (found == true) {
              _showFab = true;
              widget.model.message = 'Add to Collection';
            } else {
              _showFab = false;
            }
            if (mounted) setState(() {});
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: Row(
          children: [
            IconButton(
              onPressed: () => context.go("/"),
              padding: EdgeInsets.symmetric(horizontal: 0),
              icon: Icon(Icons.keyboard_double_arrow_left, size: 32),
            ),
            IconButton(
              onPressed:
                  () async =>
                      await _controller.canGoBack()
                          ? _controller.goBack()
                          : context.mounted
                          ? context.go("/")
                          : null,
              icon: Icon(Icons.keyboard_arrow_left, size: 32),
            ),
          ],
        ),
        title: Text(widget.url.replaceFirst('https://', '')),
      ),
      body: WebViewWidget(controller: _controller),
      floatingActionButton:
          _showFab
              ? FloatingActionButton.extended(
                onPressed:
                    () async =>
                        widget.model.fetch(await _controller.currentUrl()),
                label: ListenableBuilder(
                  listenable: widget.model,
                  builder: (context, _) => Text(widget.model.message),
                ),
                backgroundColor: Theme.of(context).primaryColor.withAlpha(150),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
