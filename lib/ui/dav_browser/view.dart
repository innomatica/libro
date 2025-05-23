import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:logging/logging.dart';

import '../../model/webdav.dart';
import '../../utils/helpers.dart';
import './model.dart';

class DavBrowser extends StatelessWidget {
  DavBrowser({super.key, required this.model});
  final DavBrowserModel model;
  // ignore: unused_field
  final _logger = Logger('DavBrowserModel');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final items = model.davItems;
        final currentPath = model.currentPath;
        final showFab = model.hasMediaItems;
        final errorTextStyle = TextStyle(
          color: Theme.of(context).colorScheme.error,
        );
        return Scaffold(
          // app bar
          appBar: AppBar(
            leadingWidth: 110,
            leading: Row(
              children: [
                // double arrow left
                IconButton(
                  icon: Icon(Icons.keyboard_double_arrow_left, size: 32),
                  onPressed: () => context.go("/"),
                ),
                // arrow left
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_left, size: 32),
                  onPressed:
                      () =>
                          currentPath == model.server?.root
                              ? context.go("/")
                              : model.setPath(
                                currentPath.substring(
                                  0,
                                  currentPath.lastIndexOf('/'),
                                ),
                              ),
                ),
              ],
            ),
            // title
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // server title
                Text(model.server?.title ?? ''),
                // current path
                Text(
                  currentPath,
                  style: TextStyle(
                    fontSize: 12.0,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {
                  context.go(
                    Uri(
                      path: "/dav_server",
                      queryParameters: {
                        "serverId": model.server?.id.toString(),
                      },
                    ).toString(),
                  );
                },
                icon: Icon(Icons.settings_rounded),
              ),
            ],
          ),
          // body
          body:
              model.error.isEmpty
                  // webdav props: files and directories
                  ? ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isDir =
                          item.resourceType == WebDavItemType.collection;
                      return isDir && item.href == currentPath
                          ? const SizedBox() // hide current dir
                          : ListTile(
                            leading:
                                isDir
                                    ? Icon(Icons.folder_rounded)
                                    : Icon(
                                      getMimeIcon(
                                        item.contentType ??
                                            ContentType('text', 'html'),
                                      ),
                                    ),
                            title: Text(item.href.split('/').last),
                            onTap:
                                isDir ? () => model.setPath(item.href) : null,
                          );
                    },
                  )
                  // error
                  : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child:
                          model.error.contains('signin')
                              ? FilledButton.tonal(
                                child: Text(
                                  "Sign in to ${model.server?.title}",
                                ),
                                onPressed:
                                    () async => await model.startOAuth(context),
                              )
                              : Text(
                                model.error.replaceAll(RegExp(r"<[^>]*>"), ''),
                                style: errorTextStyle,
                              ),
                    ),
                  ),
          floatingActionButton:
              showFab
                  ? FloatingActionButton.extended(
                    onPressed: () async {
                      final res = await model.addToResources();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res
                                  ? "Item added / updated"
                                  : "Failed to fetch data",
                            ),
                          ),
                        );
                      }
                    },
                    label: Text('Add to Booshelf'),
                  )
                  : null,
        );
      },
    );
  }
}
