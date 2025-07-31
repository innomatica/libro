import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:xml/xml.dart';

import '../../../model/webdav.dart';
import '../../../utils/helpers.dart';

enum WebDavExCause { http }

class WebDavClientException implements Exception {
  WebDavClientException(this.cause, {this.statusCode, this.details});
  WebDavExCause cause;
  int? statusCode;
  String? details;

  @override
  String toString() => '${cause.name} - $statusCode:$details';
}

class WebDavClient {
  // ignore: unused_field
  final _logger = Logger('WebDavClient');

  Future<List<WebDavItem>> propFind({
    required String url,
    required Map<String, String>? headers,
  }) async {
    if (headers == null) {
      headers = {'content-type': 'text/xml', 'Depth': '1'};
    } else {
      headers["content-type"] = "text/xml";
      headers["Depth"] = "1";
    }

    // http client
    final client = http.Client();
    final request = http.Request('PROPFIND', Uri.parse(url));
    // header
    request.headers.addAll(headers);
    // body
    request.body = _getRequestXml('PROPFIND');
    // result
    http.StreamedResponse res;
    String body;

    // send request
    try {
      res = await client.send(request);
      body = await res.stream.transform(utf8.decoder).join();
      // _logger.fine('body:$body');
    } on Exception catch (e) {
      /*
      If you get "SocketException: OS Error: Connection refused, errno=111"
      and if you are connecting to "localhost" from an emulator then check the 
      following article:

      https://stackoverflow.com/questions/55785581/socketexception-os-error-connection-refused-errno-111-in-flutter-using-djan

      Basically, you need to use "10.0.2.2" instead of "localhost" and need to
      add it to the trusted domain of the nextcloud instance

      podman exec --user www-data -it {container name} php occ config:system:set trusted_domains 10 --value="10.0.2.2"
      */
      _logger.warning(e.toString());
      rethrow;
    } finally {
      client.close();
    }
    // accept only with status codes 200 and 207
    if (res.statusCode != 200 && res.statusCode != 207) {
      throw WebDavClientException(
        WebDavExCause.http,
        statusCode: res.statusCode,
        details: res.toString(),
      );
    }

    // decode XML
    try {
      final resources = <WebDavItem>[];
      final xmlDoc = XmlDocument.parse(body);
      // _logger.fine('xmlDoc: $xmlDoc');
      // iterate over all response elements
      for (final response in xmlDoc.rootElement.findElements(
        'response',
        namespace: '*',
      )) {
        String? href;
        DateTime? creationDate;
        String? displayName;
        String? contentLanguage;
        int? contentLength;
        ContentType? contentType;
        String? etag;
        DateTime? lastModified;
        WebDavItemType? resourceType;
        // int? id;
        // int? fileId;
        // int? favorite;
        // String? ownerDisplayName;
        // int? size;
        // String? permissions;
        // int? containedFolderCount;
        // int? containedFileCount;
        for (final item in response.childElements) {
          if (item.name.local == 'href') {
            // D:href => http encoded
            href = Uri.decodeFull(item.innerText);
          } else if (item.name.local == 'propstat') {
            // D:propstat => D:prop + D:status
            for (final subItem in item.childElements) {
              if (subItem.name.local == 'status') {
                // D:status
                if (!subItem.innerText.contains('200')) {
                  // ignore if not 200 OK
                  continue;
                }
              } else if (subItem.name.local == 'prop') {
                // D:prop
                for (final subSubItem in subItem.childElements) {
                  // logDebug('prop item:$subSubItem');
                  switch (subSubItem.name.local) {
                    case 'creationdate':
                      try {
                        creationDate = HttpDate.parse(subSubItem.innerText);
                      } catch (e) {
                        // logDebug(subSubItem.innerText);
                        // probably ISO format(2023-10-09T01:27:53Z)
                        // logDebug(e.toString());
                        creationDate = DateTime.tryParse(subSubItem.innerText);
                      }
                      break;
                    case 'displayname':
                      displayName = subSubItem.innerText.replaceAll('"', '');
                      break;
                    case 'getcontentlanguage':
                      contentLanguage = subSubItem.innerText.replaceAll(
                        '"',
                        '',
                      );
                      break;
                    case 'getcontentlength':
                      contentLength = int.tryParse(subSubItem.innerText);
                      break;
                    case 'getcontenttype':
                      final ctype = subSubItem.innerText;
                      contentType = ctype.contains('/')
                          ? ContentType(
                              ctype.split('/')[0],
                              ctype.split('/')[1],
                            )
                          : null;
                      break;
                    case 'getetag':
                      etag = subSubItem.innerText.replaceAll('"', '');
                      break;
                    case 'getlastmodified':
                      try {
                        lastModified = HttpDate.parse(subSubItem.innerText);
                      } catch (e) {
                        // logDebug(e.toString());
                        creationDate = DateTime.tryParse(subSubItem.innerText);
                      }
                      break;
                    case 'resourcetype':
                      if (subSubItem.innerXml.contains('collection')) {
                        resourceType = WebDavItemType.collection;
                      }
                      break;
                    // //
                    // // OpenCloud dialects
                    // //
                    // case 'id':
                    //   id = int.tryParse(subSubItem.innerText);
                    //   break;
                    // case 'fileid':
                    //   fileId = int.tryParse(subSubItem.innerText);
                    //   break;
                    // case 'favorite':
                    //   favorite = int.tryParse(subSubItem.innerText);
                    //   break;
                    // case 'owner-display-name':
                    //   ownerDisplayName = subSubItem.innerText;
                    //   break;
                    // case 'size':
                    //   size = int.tryParse(subSubItem.innerText);
                    //   break;
                    // case 'permissions':
                    //   permissions = subSubItem.innerText;
                    //   break;
                    // //
                    // // NextCloud dialects
                    // //
                    // case 'contained-folder-count':
                    //   containedFolderCount = int.tryParse(subSubItem.innerText);
                    //   break;
                    // case 'contained-file-count':
                    //   containedFileCount = int.tryParse(subSubItem.innerText);
                    //   break;
                    default:
                      break;
                  }
                }
              }
            }
          }
        }
        if (href != null && href.isNotEmpty) {
          // remove trailing slash
          href = href.replaceAll(RegExp(r'/$'), '');
          // in case webdav does not understand certain audio mime-types
          // logDebug('href: $href, contentType: $contentType');
          if (contentType == null ||
              (contentType.primaryType == 'application' &&
                  contentType.subType == 'octet-stream')) {
            contentType = getContentTypeFromUriString(href);
            // if (href.endsWith('aac')) {
            //   contentType = ContentType('audio', 'x-aac');
            // } else if (href.endsWith('flac')) {
            //   contentType = ContentType('audio', 'x-flac');
            // } else if (href.endsWith('m4a')) {
            //   contentType = ContentType('audio', 'x-m4a');
            // } else if (href.endsWith('m4b')) {
            //   contentType = ContentType('audio', 'x-m4b');
            // }
          }
          resources.add(
            WebDavItem(
              // remove trailing slash is desired
              href: href,
              creationDate: creationDate,
              displayName: displayName,
              contentLanguage: contentLanguage,
              contentLength: contentLength,
              contentType: contentType,
              etag: etag,
              lastModified: lastModified,
              resourceType: resourceType,
            ),
          );
          // logDebug('resource: ${resources[resources.length - 1].toString()}');
        }
      }

      resources.sort(((a, b) => (a.href).compareTo(b.href)));
      // logDebug('resources: ${resources.toString()}');
      return resources;
    } on Exception catch (e) {
      // failed to parse xml body
      _logger.severe(e.toString());
      rethrow;
    }
  }

  static String _getRequestXml(String method) {
    String xml = '<?xml version="1.0" encoding="UTF-8"?>';
    if (method == 'PROPFIND') {
      xml =
          '$xml '
          '<d:propfind xmlns:d="DAV:"'
          '   xmlns:oc="http://owncloud.org/ns"'
          '   xmlns:nc="http://nextcloud.org/ns">'
          ' <d:prop>'
          '   <d:creationdate />'
          '   <d:displayname />'
          '   <d:getcontentlanguage />'
          '   <d:getcontentlength />'
          '   <d:getcontenttype />'
          '   <d:getetag />'
          '   <d:getlastmodified />'
          '   <d:resourcetype />'
          // // opencloud dialects
          // '   <oc:id />'
          // '   <oc:fileid />'
          // '   <oc:favorite />'
          // '   <oc:comments-href />'
          // '   <oc:comments-count />'
          // '   <oc:comments-unread />'
          // '   <oc:owner-id />'
          // '   <oc:owner-display-name />'
          // '   <oc:share-types />'
          // '   <oc:checksums />'
          // '   <nc:has-preview />'
          // '   <oc:size />'
          // '   <oc:permissions />'
          // // nextcloud dialects
          // '   <nc:rich-workspace />'
          // '   <nc:contained-folder-count />'
          // '   <nc:contained-file-count />'
          ' </d:prop>'
          '</d:propfind>';
    }
    return xml;
  }
}
