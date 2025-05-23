import 'dart:convert';
import 'dart:io';

import 'webdav.dart';

class ResourceItem {
  int index;
  String title;
  String uri;
  int? size;
  int? duration;
  String? thumbnail;
  String? language;
  ContentType? type;

  ResourceItem({
    required this.index,
    required this.title,
    required this.uri,
    this.size,
    this.duration,
    this.thumbnail,
    this.language,
    this.type,
  });

  factory ResourceItem.fromMap(Map<String, dynamic> map) => ResourceItem(
    index: map['index'],
    title: map['title'],
    uri: map['uri'],
    size: map['size'],
    duration: map['duration'],
    thumbnail: map['thumbnail'],
    language: map['language'],
    type: ContentType.parse(map['type']),
  );

  Map<String, Object?> toMap() => {
    'index': index,
    'title': title,
    'uri': uri,
    'size': size,
    'duration': duration,
    'thumbnail': thumbnail,
    'language': language,
    'type': type.toString(),
  };

  @override
  String toString() => toMap().toString();
}

class Bookmark {
  int index;
  int position;

  Bookmark({required this.index, required this.position});

  factory Bookmark.fromMap(Map<String, dynamic> data) =>
      Bookmark(index: data['index'], position: data['position']);

  Map<String, Object?> toMap() {
    return {'index': index, 'position': position};
  }

  @override
  String toString() => toMap().toString();
}

class Resource {
  String resourceId;
  String category;
  String genre;
  String title;
  String author;
  String? description;
  String? thumbnail;
  String? keywords;
  List<ContentType> mediaTypes;
  List<ResourceItem> items;
  Bookmark? bookmark;
  int? serverId;
  Map<String, dynamic>? extra;
  // Map<String, String>? headers; // populated during SQL query
  WebDavAuth? auth;

  Resource({
    required this.resourceId,
    required this.category,
    required this.genre,
    required this.title,
    required this.author,
    this.description,
    this.thumbnail,
    this.keywords,
    required this.mediaTypes,
    required this.items,
    this.bookmark,
    this.serverId,
    this.extra,
    this.auth,
  });

  factory Resource.fromSqlite(Map<String, Object?> row) {
    return Resource(
      resourceId: row['resource_id'] as String,
      category: row['category'] as String,
      genre: row['genre'] as String,
      title: row['title'] as String,
      author: row['author'] as String,
      description: row['description'] as String?,
      thumbnail: row['thumbnail'] as String?,
      keywords: row['keywords'] as String?,
      items:
          jsonDecode(
            row['items'] as String,
          ).map<ResourceItem>((e) => ResourceItem.fromMap(e)).toList(),
      mediaTypes:
          jsonDecode(
            row['media_types'] as String,
          ).map<ContentType>((e) => ContentType.parse(e)).toList(),
      bookmark:
          row['bookmark'] != null
              ? Bookmark.fromMap(jsonDecode(row['bookmark'] as String))
              : null,
      serverId: row['server_id'] != null ? row['server_id'] as int : null,
      extra: row['extra'] != null ? jsonDecode(row['extra'] as String) : null,
      auth:
          row['auth'] != null
              ? WebDavAuth.fromMap(jsonDecode(row['auth'] as String))
              : null,
    );
  }

  Map<String, Object?> toSqlite() => {
    'resource_id': resourceId,
    'category': category,
    'genre': genre,
    'title': title,
    'author': author,
    'description': description,
    'thumbnail': thumbnail,
    'keywords': keywords,
    'media_types': jsonEncode(mediaTypes.map((e) => e.toString()).toList()),
    'items': jsonEncode(items.map((e) => e.toMap()).toList()),
    'bookmark': bookmark != null ? jsonEncode(bookmark!.toMap()) : null,
    'server_id': serverId,
    'extra': extra != null ? jsonEncode(extra) : null,
    // auth is a db field
  };

  @override
  String toString() {
    // description is too long to show
    return (toSqlite()..remove('description')).toString();
  }
}
