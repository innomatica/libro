import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import '../../model/resource.dart';
import '../../utils/helpers.dart';
import '../../utils/miniplayer.dart';
import 'model.dart';

class ResourceView extends StatelessWidget {
  ResourceView({super.key, required this.model});

  final ResourceViewModel model;
  // ignore: unused_field
  final _logger = Logger('ResourceView');

  Widget _buildDownloadButton() {
    return ListenableBuilder(
      listenable: model.downloader,
      builder: (context, _) {
        if (model.downloader.resourceId == model.resource?.resourceId) {
          // downloader are handling current resource
          return IconButton(
            onPressed: model.dataLocal
                ? null
                : () {
                    if (model.downloader.running) {
                      // currently downloading
                      model.downloader.cancel();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'download is going to be canceled soon',
                          ),
                        ),
                      );
                    } else {
                      // currently not downloading => resume
                      model.downloader.run(model.resource?.resourceId);
                    }
                  },
            icon: Icon(
              model.downloader.running
                  ? Icons.file_download_off_rounded
                  : Icons.file_download_rounded,
            ),
          );
        } else {
          // downloader is not handling current resource or idle
          return IconButton(
            onPressed: model.downloader.running || model.dataLocal
                ? null
                : () => model.downloader.run(model.resource?.resourceId),
            icon: Icon(Icons.download),
          );
        }
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    bool expandDescription = false;
    return model.running
        ? Center(child: CircularProgressIndicator())
        : model.error.isEmpty
        ? SingleChildScrollView(
            padding: EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 8,
              children: [
                ListenableBuilder(
                  listenable: model.downloader,
                  builder: (context, _) =>
                      model.downloader.running &&
                          model.downloader.resourceId ==
                              model.resource?.resourceId
                      ? Stack(
                          children: [
                            LinearProgressIndicator(
                              value: model.downloader.result,
                            ),
                            Opacity(
                              opacity: 0.3,
                              child: LinearProgressIndicator(),
                            ),
                          ],
                        )
                      : SizedBox(),
                ),
                Banner(
                  title: model.resource!.title.split('-').first,
                  subtitle: model.resource!.title.contains(' - ')
                      ? model.resource!.title.split('-').last
                      : null,
                  image: model.image,
                ),
                // description
                model.resource!.description != null
                    ? StatefulBuilder(
                        builder: (context, setState) {
                          return GestureDetector(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                model.resource!.description ?? '',
                                maxLines: expandDescription ? 30 : 3,
                                overflow: TextOverflow.fade,
                              ),
                            ),
                            onTap: () => setState(
                              () => expandDescription = !expandDescription,
                            ),
                          );
                        },
                      )
                    : SizedBox(),
                // items
                ListenableBuilder(
                  listenable: model,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: model.resource!.items.map((e) {
                        return ItemTile(
                          item: e,
                          callback: () => _playContent(e, context),
                          playing: e.index == model.currentItemIndex,
                          marked: e.index == model.bookmarkItemIndex,
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          )
        : Center(
            child: model.error.contains('signin')
                ? FilledButton(
                    onPressed: () => model.restartOAuth(context),
                    child: Text('Authentication Required'),
                  )
                : Text(model.error),
          );
  }

  void _playContent(ResourceItem item, BuildContext context) async {
    // _logger.fine("item:$item");
    if (item.type?.primaryType == 'audio') {
      model.playItem(item);
    } else {
      Widget? widget;
      if (item.type?.primaryType == 'image') {
        final file = await model.getItemFile(item);
        if (file != null) {
          widget = Image(image: FileImage(file));
        }
      } else if (item.type?.primaryType == 'application' &&
          item.type?.subType == 'pdf') {
        final file = await model.getItemFile(item);
        if (file != null) {
          widget = PDFView(filePath: file.path);
        }
      }
      if (widget != null) {
        context.mounted
            ? showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    contentPadding: EdgeInsets.all(0),
                    content: SizedBox(width: double.maxFinite, child: widget!),
                  );
                },
              )
            : null;
      } else {
        context.mounted
            ? ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('unsupported media type: ${item.type}')),
              )
            : null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        // logger.fine(snapshot);
        // bool expandDescription = false;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => context.go("/"),
              icon: Icon(Icons.chevron_left_rounded, size: 36),
            ),
            title: Text(
              model.resource?.author ?? '...',
              style: TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // download button
              _buildDownloadButton(),
              // delete button
              IconButton(
                onPressed: () async {
                  await model.deleteResource();
                  if (context.mounted) {
                    context.go("/");
                  }
                },
                icon: Icon(
                  Icons.delete_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          body: _buildBody(context),
          // bottom navigation bar does not hide content
          bottomNavigationBar: MiniPlayer(),
          bottomSheet: ListenableBuilder(
            listenable: model.downloader,
            builder: (context, _) {
              if (model.downloader.resourceId == model.resource?.resourceId) {
                if (model.downloader.completed) {
                  // clear result
                  model.downloader.clearResult();
                  // refresh screen
                  model.load(model.resource?.resourceId);
                }
                return model.downloader.error.isNotEmpty
                    ? Text(
                        model.downloader.error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : SizedBox();
              } else {
                return SizedBox();
              }
            },
          ),
        );
      },
    );
  }
}

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    this.callback,
    this.playing,
    this.marked,
  });
  final ResourceItem item;
  final VoidCallback? callback;
  final bool? playing;
  final bool? marked;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: playing == true ? Theme.of(context).colorScheme.onSecondary : null,
      child: ListTile(
        onTap: callback,
        visualDensity: VisualDensity.compact,
        selected: marked ?? false,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8.0,
          children: [
            Icon(
              getMimeIcon(item.type),
              color: Theme.of(context).colorScheme.tertiary,
            ),
            Expanded(child: Text(item.title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        trailing: Icon(getSourceIcon(item.uri)),
      ),
    );
  }
}

class Banner extends StatelessWidget {
  const Banner({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
  });
  final ImageProvider image;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        // thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: Image(
            image: image,
            // width: 200,
            width: double.maxFinite,
            height: 150,
            fit: BoxFit.cover,
            opacity: const AlwaysStoppedAnimation(0.5),
          ),
        ),
        // title
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            spacing: 8,
            children: [
              // main title
              OutlinedText(title, fontSize: 22, fontWeight: FontWeight.w600),
              // subtitle
              subtitle != null
                  ? OutlinedText(subtitle!, fontSize: 15)
                  : SizedBox(),
            ],
          ),
        ),
      ],
    );
  }
}

class OutlinedText extends StatelessWidget {
  const OutlinedText(this.data, {super.key, this.fontSize, this.fontWeight});
  final String data;
  final double? fontSize;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // Stroked text as border.
        Text(
          data,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              // ..color = Colors.grey[500]!,
              ..color = Theme.of(context).colorScheme.outline,
          ),
        ),
        // Solid text as fill.
        Text(
          data,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
        ),
      ],
    );
  }
}
