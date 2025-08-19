import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import '../../../model/resource.dart';
import '../../../utils/helpers.dart';

enum WebScraperExCause { parse, http }

class WebScraperException implements Exception {
  WebScraperException(this.cause, {this.statusCode, this.details});
  WebScraperExCause cause;
  int? statusCode;
  String? details;
}

class WebScraper {
  final _uuid = Uuid();
  // ignore: unused_field
  final _logger = Logger('WebScraper');

  Future<Resource> scrap(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        return await _decodeHTML(res.body, url);
      }
      throw WebScraperException(
        WebScraperExCause.http,
        statusCode: res.statusCode,
        details: res.body,
      );
    } on Exception {
      rethrow;
    }
  }

  Future<Resource> _decodeHTML(String html, String url) async {
    Resource? resource;
    // _logger.fine('url: $url');
    // _logger.fine('html: $html');
    final document = parse(html);
    if (url.contains('archive.org')) {
      //
      // Internet Archive
      //
      final attrs = <String, dynamic>{};
      // collect meta tag attributes
      final metas = document.getElementsByTagName('meta');
      for (final item in metas) {
        if (item.attributes['property'] == 'twitter:title') {
          attrs['title'] = item.attributes['content']?.split(':')[0].trim();
        } else if (item.attributes['property'] == 'twitter:image') {
          attrs['imageUrl'] = item.attributes['content']!;
        } else if (item.attributes['property'] == 'twitter:description') {
          attrs['description'] = item.attributes['content']!;
        }
      }

      // resource items
      final items = <ResourceItem>[];
      // itemtype="http://schema.org/AudioOject"
      final theatre = document.querySelectorAll(
        '#theatre-ia-wrap > div[itemtype="http://schema.org/AudioObject"]',
      );
      for (final item in theatre) {
        String? title;
        String? uri;
        String? durString;
        // _logger.fine('item: ${item.innerHtml}');
        for (final child in item.children) {
          // _logger.fine('child: ${child.localName}');
          // _logger.fine('child: ${child.attributes}');
          if (child.attributes.containsKey('itemprop')) {
            if (child.attributes['itemprop'] == 'name') {
              // title
              title = child.attributes['content'];
            } else if (child.attributes['itemprop'] == 'associatedMedia') {
              // url
              uri = child.attributes['href']?.split('?').first;
            } else if (child.attributes['itemprop'] == 'duration') {
              // duration in PT0MssssS format
              durString = child.attributes['content']?.trim();
            }
          }
        }
        if (title != null && uri != null) {
          items.add(
            ResourceItem(
              index: items.length,
              title: title.trim(),
              uri: uri.trim(),
              duration: _customTimeToSeconds(durString) ?? 0,
              type: getContentTypeFromUriString(uri),
            ),
          );
        }
      }

      // title
      final title =
          document.querySelector('h1.item-title')?.text.trim() ??
          attrs['title'];
      // author
      final author =
          document.querySelector('h1.item-title ~ dl  a')?.text.trim() ??
          'Unknown';
      // keywords
      final keywords = document
          .querySelector('dd[itemprop="keywords"]')
          ?.text
          .trim();
      // description
      final description =
          document.querySelector('#descript')?.text.trim() ??
          attrs['description'];
      // thumbnail
      final thumbnail =
          (document
                      .querySelector('div[slot="image"] > img')
                      ?.attributes['src'] ??
                  attrs['imageUrl'])
              .split('?')
              .first;
      // mediaTypes
      Set<ContentType> mediaTypeSet = {};
      for (final item in items) {
        if (item.type != null) {
          mediaTypeSet.add(item.type!);
        }
      }
      if (items.isNotEmpty) {
        resource = Resource(
          resourceId: _uuid.v5(Namespace.url.value, url),
          category: 'Unknown',
          genre: 'Unknown',
          title: title ?? 'Unknown',
          author: author,
          description: description,
          thumbnail: thumbnail,
          keywords: keywords,
          mediaTypes: mediaTypeSet.toList(),
          items: items,
          extra: {'source': 'Internet Archive', 'url': url},
        );
      }
    } else if (url.contains('librivox.org')) {
      //
      // LibriVox
      //
      String? urlRss;
      String? librivoxId;
      // int? duration;
      String? textUrl;
      final items = <ResourceItem>[];

      // class: page book-page
      final bookPage = document.querySelector('.page.book-page');
      if (bookPage != null) {
        // album image
        final imageUrl = bookPage
            .querySelector('.book-page-book-cover img')
            ?.attributes['src'];
        // title
        final title = bookPage.querySelector('h1')?.text ?? 'Unknown Title';
        // authors
        final author = bookPage
            .querySelector('.book-page-author a')
            ?.text
            .split('(')[0] // remove DOB,DOD
            .trim();
        // description
        final description = bookPage.querySelector('.description')?.text.trim();
        // genre and lanugage
        // <p class="book-page-genre"><span>Genre(s):</span> *Non-fiction, </p>
        // <p class="book-page-genre"><span>Language:</span> English</p>
        var language = 'english';
        var genre = 'unknown';
        for (final elem in bookPage.querySelectorAll('.book-page-genre')) {
          final inner = elem.innerHtml;
          if (inner.contains('Language')) {
            language = inner.split('</span>')[1].trim().toLowerCase();
          } else if (inner.contains('Genre')) {
            genre = inner.split('</span>')[1].trim().toLowerCase();
          }
        }

        // class: sidebar book-page
        final sidebar = document.querySelector('.sidebar.book-page');
        if (sidebar != null) {
          // get all dt tags
          final dts = sidebar.getElementsByTagName('dt');
          // go over dt tags
          for (final dt in dts) {
            if (dt.text.contains('RSS')) {
              // RSS feed url
              final dd = dt.nextElementSibling;
              urlRss = dd?.firstChild?.attributes['href'];
              if (urlRss != null) {
                librivoxId = urlRss.split('/').last;
              }
              // } else if (dt.text.contains('Running Time')) {
              //   // running time
              //   final dd = dt.nextElementSibling;
              //   duration = _iso8601TimeToSeconds(dd?.text);
            }
          }
          // get all p a tags
          final pas = sidebar.querySelectorAll('p a');
          for (final pa in pas) {
            if (pa.text.contains('Online text')) {
              textUrl = pa.attributes['href'];
            }
          }
        }

        // items
        final tableBody = bookPage.querySelector('.chapter-download tbody');
        if (tableBody != null) {
          final trs = tableBody.getElementsByTagName('tr');
          int index = 0;
          String title = 'Unknown';
          String uri = '';
          int? duration;

          for (final tr in trs) {
            duration = null;
            // map must be defined inside
            final info = <String, dynamic>{};
            // logDebug('row: ${tr.text}');
            final tds = tr.getElementsByTagName('td');
            for (final td in tds) {
              final atag = td.querySelector('a');
              // logDebug('atag: ${atag?.text}');
              if (atag == null) {
                // duration (comes first) or language
                // logDebug('duation: ${td.text}');
                duration ??= _iso8601TimeToSeconds(td.text);
              } else if (atag.className == 'play-btn') {
                // uri first candidate
                uri = atag.attributes['href'] ?? '';
              } else if (atag.className == 'chapter-name') {
                // title
                title = atag.text.trim();
                // uri second candidate
                if (atag.attributes['href'] != null) {
                  uri = atag.attributes['href']!;
                }
              } else if (atag.text.contains('Etext')) {
                info['textUrl'] = atag.attributes['href'];
              }
            }

            items.add(
              ResourceItem(
                index: index,
                title: title.trim().replaceFirst(':', '-'),
                uri: uri.trim(),
                duration: duration ?? 0,
                language: language,
                type: getContentTypeFromUriString(uri),
              ),
            );
            index++;
          }
        }

        // mediaTypes
        Set<ContentType> mediaTypeSet = {};
        for (final item in items) {
          if (item.type != null) {
            mediaTypeSet.add(item.type!);
          }
        }
        if (items.isNotEmpty) {
          resource = Resource(
            resourceId: _uuid.v5(Namespace.url.value, url),
            category: 'Audiobook',
            genre: genre,
            title: title.replaceFirst(':', '-'),
            author: author ?? '',
            description: description,
            thumbnail: imageUrl?.trim(),
            keywords: '$genre,$author',
            items: items,
            mediaTypes: mediaTypeSet.toList(),
            extra: {
              'num_sections': items.length,
              'bookId': librivoxId,
              'urlRss': urlRss?.trim(),
              'siteUrl': url,
              'textUrl': textUrl?.trim(),
            },
          );
        }
      }
    } else if (url.contains('legamus.eu')) {
      //
      // Legamus
      //
      // title
      final title =
          document.querySelector('h1.entry-title')?.innerHtml ??
          "Title Unknown";
      // author
      String? author =
          document.querySelector('.entry-content strong')?.innerHtml ??
          "Author Unknown";
      if (author.contains('(')) {
        author = author.split('(')[0].trim();
      }
      // NOTE: this is a fragile operation
      final description = document
          .querySelectorAll('.entry-content p')[2]
          .innerHtml;
      // image url
      String? imageUrl = document
          .querySelector('.entry-content img')
          ?.attributes['src'];
      if (imageUrl != null && !imageUrl.startsWith('http')) {
        imageUrl = 'https://legamus.eu${imageUrl.trim()}';
      }

      // int? duration;
      final items = <ResourceItem>[];

      // audio page url
      final audioUrl = document
          .querySelector('li a[href*="listen.legamus.eu"]')
          ?.attributes['href'];
      if (audioUrl != null) {
        final res = await http.get(Uri.parse(audioUrl));
        if (res.statusCode == 200) {
          final audioPage = parse(res.body);
          final rows = audioPage.querySelectorAll('#player_table tr');
          // logDebug('rows: $rows');
          int index = 0;
          for (final row in rows) {
            // logDebug('row: $row');
            final titleRow = row.querySelector('.section span')?.innerHtml;
            if (titleRow != null) {
              final uri =
                  row.querySelector('.downloadlinks a')?.attributes['href'] ??
                  "";
              final title = titleRow.split('(')[0].trim();
              final duration = _iso8601TimeToSeconds(
                RegExp(r'\(([^)]+)\)').firstMatch(titleRow)?.group(1),
              );

              items.add(
                ResourceItem(
                  index: index,
                  title: title,
                  uri: '${audioUrl.trim()}/${uri.trim()}',
                  size: duration ?? 0,
                ),
              );
              index = index + 1;
            }
          }
        }
      }

      if (items.isNotEmpty) {
        resource = Resource(
          resourceId: _uuid.v5(Namespace.url.value, url),
          category: '',
          genre: '',
          title: title,
          author: author,
          description: description,
          thumbnail: imageUrl?.trim(),
          mediaTypes: [],
          items: items,
          extra: {'source': 'Legamus', 'url': url},
        );
      }
    }
    // _logger.fine(resource);
    if (resource != null) {
      return resource;
    }
    throw WebScraperException(
      WebScraperExCause.parse,
      details: 'unknown site: failed to parse HTML',
    );
  }

  int? _iso8601TimeToSeconds(String? timeString) {
    int? result;
    if (timeString != null && timeString.isNotEmpty) {
      final times = timeString.split(':');
      if (times.length == 3) {
        result =
            (int.tryParse(times[0]) ?? 0) * 3600 +
            (int.tryParse(times[1]) ?? 0) * 60 +
            (int.tryParse(times[2]) ?? 0);
      } else if (times.length == 2) {
        result =
            (int.tryParse(times[0]) ?? 0) * 60 + (int.tryParse(times[1]) ?? 0);
      }
    }
    // logDebug('iso8601time to seconds:$timeString => $result');
    return result;
  }

  int? _customTimeToSeconds(String? timeString) {
    // internet archive uses PT0MxxxxS format
    int? result;
    if (timeString != null && timeString.isNotEmpty) {
      result = int.tryParse(timeString.substring(4, timeString.length - 1));
    }
    // logDebug('custom time to seconds:$timeString => $result');
    return result;
  }

  // ContentType? _getMediaTypeFromUri(String? uri) {
  //   if (uri != null) {
  //     final ext = uri.split('?')[0].split('.').reversed.elementAt(0);
  //     _logger.fine('uri:$uri, extention: $ext');
  //     if (['pdf', 'epub'].contains(ext)) {
  //       return ContentType('application', ext);
  //     } else if (['aac', 'm4a', 'm4b', 'mp3', 'ogg', 'wav', 'weba']
  //         .contains(ext)) {
  //       return ContentType('audio', ext);
  //     } else if (['bmp', 'gif', 'jpeg', 'jpg', 'png', 'svg', 'webp']
  //         .contains(ext)) {
  //       return ContentType('image', ext);
  //     } else if (['mp4', 'mpeg', 'webm'].contains(ext)) {
  //       return ContentType('video', ext);
  //     } else if (['html', 'txt'].contains(ext)) {
  //       return ContentType('text', ext);
  //     }
  //   }
  //   return null;
  // }
}
