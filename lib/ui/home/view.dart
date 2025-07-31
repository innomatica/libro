import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/helpers.dart';
import '../../model/webdav.dart';
import '../../utils/constants.dart';
import '../../utils/miniplayer.dart';
import './model.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.model});
  final HomeViewModel model;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // ignore: unused_field
  final _logger = Logger('HomeView');

  int counter = 0;
  Timer? timer;

  void setSleepTimer() {
    final player = context.read<AudioPlayer>();

    if (counter == 0) {
      counter = 30 * 60;
    } else if (counter > 20 * 60) {
      counter = 20 * 60;
    } else if (counter > 10 * 60) {
      counter = 10 * 60;
    } else if (counter > 5 * 60) {
      counter = 5 * 60;
    } else {
      counter = 0;
      timer?.cancel();
      setState(() {});
    }

    if (counter > 0) {
      if (timer == null || !timer!.isActive) {
        timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (player.playing) {
            counter--;
            if (counter <= 0) {
              player.stop();
              timer.cancel();
            }
            setState(() {});
          }
        });
      }
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 24,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          ListTile(
            title: Text('Source code repository'),
            subtitle: Text('github'),
            onTap: () => launchUrl(Uri.parse(sourceRepository)),
          ),
          ListTile(
            title: Text('App version'),
            subtitle: Text(appVersion),
            onTap: () => launchUrl(Uri.parse(sourceRepository)),
          ),
          ListTile(
            title: Text('Developer'),
            subtitle: Text('innomatic'),
            onTap: () => launchUrl(Uri.parse(developerWebsite)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // _logger.fine('running:${model.running}');
    final player = context.read<AudioPlayer>();
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) {
        return Scaffold(
          // app bar
          appBar: AppBar(
            title: Text(appName),
            actions: [
              // sleep button
              StreamBuilder<bool>(
                stream: player.playingStream,
                builder: (context, snapshot) {
                  return TextButton.icon(
                    onPressed:
                        snapshot.data == true ? () => setSleepTimer() : null,
                    icon: Icon(Icons.timelapse_rounded, size: 24),
                    label:
                        counter == 0
                            ? SizedBox()
                            : Text((counter ~/ 60 + 1).toString()),
                  );
                },
              ),
            ],
          ),
          body:
              widget.model.running
                  ? Center(child: CircularProgressIndicator())
                  : widget.model.error != ""
                  ? Center(child: Text(widget.model.error))
                  : LayoutBuilder(
                    builder: (context, constraint) {
                      return widget.model.items.isNotEmpty
                          ? constraint.maxWidth <= 600
                              ? ListView(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                children:
                                    widget.model.items
                                        .map(
                                          (item) => RectTile(
                                            item: item,
                                            selected:
                                                widget
                                                    .model
                                                    .selectedResourceId ==
                                                item.res.resourceId,
                                          ),
                                        )
                                        .toList(),
                              )
                              : GridView.extent(
                                maxCrossAxisExtent: 170,
                                padding: const EdgeInsets.all(4),
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 4,
                                childAspectRatio: 0.8,
                                children:
                                    widget.model.items
                                        .map(
                                          (item) => GridTile(
                                            item: item,
                                            selected:
                                                widget
                                                    .model
                                                    .selectedResourceId ==
                                                item.res.resourceId,
                                          ),
                                        )
                                        .toList(),
                              )
                          : Center(
                            child: Image.asset(
                              bookImage,
                              width: 200,
                              height: 200,
                              opacity: const AlwaysStoppedAnimation(0.5),
                            ),
                          );
                    },
                  ),
          floatingActionButton: Opacity(
            opacity: 0.7,
            child: CustomActionButton(servers: widget.model.servers),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          // bottom navigation bar does not hide content
          bottomNavigationBar: MiniPlayer(),
          drawer: _buildDrawer(),
        );
      },
    );
  }
}

class RectTile extends StatelessWidget {
  const RectTile({super.key, required this.item, required this.selected});
  final LibroItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.0,
      color: selected ? Theme.of(context).colorScheme.tertiaryContainer : null,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Image(image: item.img, fit: BoxFit.cover),
          ),
        ),
        title: Text(
          item.res.title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // textAlign: TextAlign.left,
        ),
        subtitle: Text(
          item.res.author,
          style: TextStyle(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap:
            () => context.go(
              Uri(
                path: "/resources",
                queryParameters: {"resourceId": item.res.resourceId},
              ).toString(),
            ),
      ),
    );
  }
}

class GridTile extends StatelessWidget {
  const GridTile({super.key, required this.item, required this.selected});
  final LibroItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          () => context.go(
            Uri(
              path: "/resource",
              queryParameters: {"resourceId": item.res.resourceId},
            ).toString(),
          ),
      child: Card(
        elevation: selected ? 16 : 0,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              clipBehavior: Clip.hardEdge,
              child: AspectRatio(
                aspectRatio: 0.9,
                child: Image(
                  image: item.img,
                  width: 130,
                  // height: 130,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Text(
              item.res.title.split(' - ').first.trim(),
              style: TextStyle(fontWeight: FontWeight.w300),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            // item.res.title.split(' - ').length > 1
            //     ? Text(
            //         item.res.title.split(' - ').last.trim(),
            //         style: TextStyle(fontSize: 12),
            //         maxLines: 1,
            //         overflow: TextOverflow.ellipsis,
            //         // textAlign: TextAlign.left,
            //       )
            //     : SizedBox(),
          ],
        ),
      ),
    );
  }
}

class CustomActionButton extends StatefulWidget {
  const CustomActionButton({super.key, required this.servers});
  final List<WebDavServer> servers;

  @override
  State<CustomActionButton> createState() => _CustomActionButtonState();
}

class _CustomActionButtonState extends State<CustomActionButton> {
  final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Menu Button');

  @override
  void dispose() {
    _buttonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      childFocusNode: _buttonFocusNode,
      menuChildren: [
        // librivox
        MenuItemButton(
          onPressed:
              () => context.go(
                Uri(
                  path: "/web_browser",
                  queryParameters: {'url': librivoxUrl},
                ).toString(),
              ),
          child: Row(
            spacing: 8,
            children: [
              Icon(
                getSourceIcon('librivox'),
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const Text('Librivox'),
            ],
          ),
        ),
        // internet archive
        MenuItemButton(
          onPressed:
              () => context.go(
                Uri(
                  path: "/web_browser",
                  queryParameters: {'url': archiveUrl},
                ).toString(),
              ),
          child: Row(
            spacing: 8,
            children: [
              Icon(
                getSourceIcon('archive.org'),
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const Text('Internet Archive'),
            ],
          ),
        ),
        ...widget.servers.map(
          (e) => MenuItemButton(
            onPressed:
                () => context.go(
                  Uri(
                    path: "/dav_browser",
                    queryParameters: {'serverId': '${e.id}'},
                  ).toString(),
                ),
            child: Row(
              spacing: 8,
              children: [
                Icon(
                  getSourceIcon('http'),
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                Text(e.title),
              ],
            ),
          ),
        ),
        // new server
        MenuItemButton(
          onPressed:
              () => context.go(
                Uri(
                  path: "/dav_server",
                  queryParameters: {'serverId': 'new'},
                ).toString(),
              ),
          child: Row(
            spacing: 8,
            children: [
              Icon(
                Icons.add_rounded,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const Text('New Dav Server'),
            ],
          ),
        ),
      ],
      builder:
          (_, controller, child) => FloatingActionButton(
            onPressed:
                () =>
                    controller.isOpen ? controller.close() : controller.open(),
            child: Icon(Icons.add),
          ),
    );
  }
}
