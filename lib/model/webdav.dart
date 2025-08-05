import 'dart:convert';
import 'dart:io';

enum WebDavItemType { collection }

class WebDavItem {
  String href;
  DateTime? creationDate;
  String? displayName;
  String? contentLanguage;
  int? contentLength;
  ContentType? contentType;
  String? etag;
  DateTime? lastModified;
  WebDavItemType? resourceType;

  WebDavItem({
    required this.href,
    this.creationDate,
    this.displayName,
    this.contentLanguage,
    this.contentLength,
    this.contentType,
    this.etag,
    this.lastModified,
    this.resourceType,
  });

  @override
  String toString() {
    return {
      'href': href,
      'creationDate': creationDate?.toLocal(),
      'displayName': displayName,
      'contentLanguage': contentLanguage,
      'contentLength': contentLength,
      'contentType': contentType,
      'etag': etag,
      'lastModified': lastModified?.toLocal(),
      'resourceType': resourceType,
    }.toString();
  }
}

class NextCloudItem extends WebDavItem {
  int? id;
  int? fileId;
  int? favorite;
  String? commentsHref;
  int? commentsCount;
  bool? commentsUnread;
  int? ownerId;
  String? ownerDisplayName;
  String? shareTypes;
  String? checksums;
  bool? hasPreview;
  int? size;
  String? richWorkspace;
  int? containedFolderCount;
  int? containedFileCount;
  String? permissions;

  NextCloudItem({
    required super.href,
    super.contentLength,
    super.contentType,
    super.etag,
    super.lastModified,
    super.resourceType,
    this.id,
    this.fileId,
    this.favorite,
    this.commentsHref,
    this.commentsCount,
    this.commentsUnread,
    this.ownerId,
    this.ownerDisplayName,
    this.shareTypes,
    this.checksums,
    this.hasPreview,
    this.size,
    this.richWorkspace,
    this.containedFolderCount,
    this.containedFileCount,
    this.permissions,
  });

  @override
  String toString() {
    return {
      'href': href,
      'lastModified': lastModified?.toLocal(),
      'etag': etag,
      'resourceType': resourceType,
      'contentType': contentType,
      'contentLength': contentLength,
      'id': id,
      'fileId': fileId,
      'favorite': favorite,
      'commentsHref': commentsHref,
      'commentsCount': commentsCount,
      'commentsUnread': commentsUnread,
      'ownerId': ownerId,
      'owerDisplayName': ownerDisplayName,
      'shareTypes': shareTypes,
      'checksums': checksums,
      'hasPreview': hasPreview,
      'size': size,
      'richWorkspace': richWorkspace,
      'containedFileCount': containedFileCount,
      'containedFolderCount': containedFolderCount,
      'permissions': permissions,
    }.toString();
  }
}

enum AuthMethod { none, basic, nubis }

class WebDavAuth {
  String? username;
  String? password;
  String? authUrl;
  AuthMethod method;
  String? accessToken;
  String? refreshToken;
  int? expiresAt;
  String? scope;
  String? audience;
  String? redirectUri;
  Map<String, dynamic>? extra;

  WebDavAuth({
    this.username,
    this.password,
    this.authUrl,
    required this.method,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.scope,
    this.audience,
    this.redirectUri,
    this.extra,
  });

  Map<String, Object?> toMap() => {
    "username": username,
    "password": password,
    "auth_url": authUrl,
    "method": method.name,
    "access_token": accessToken,
    "refresh_token": refreshToken,
    "expiresAt": expiresAt,
    "scope": scope,
    "audience": audience,
    "redirect_uri": redirectUri,
    "extra": extra,
  };

  factory WebDavAuth.fromMap(Map<String, dynamic> data) => WebDavAuth(
    username: data['username'],
    password: data['password'],
    authUrl: data['auth_url'],
    method: AuthMethod.values.byName(data['method']),
    accessToken: data['access_token'],
    refreshToken: data['refresh_token'],
    expiresAt: data['expiresAt'],
    scope: data["scope"],
    audience: data["audience"],
    redirectUri: data["redirect_uri"],
    extra: data["extra"],
  );
}

class WebDavServer {
  int? id;
  String title;
  String url;
  String root;
  WebDavAuth auth;
  Map<String, dynamic>? extra;

  WebDavServer({
    this.id,
    required this.title,
    required this.url,
    required this.root,
    required this.auth,
    this.extra,
  });

  factory WebDavServer.empty() {
    return WebDavServer(
      title: 'New Server',
      url: '',
      root: '/',
      auth: WebDavAuth(method: AuthMethod.none),
      extra: {},
    );
  }

  factory WebDavServer.fromSqlite(Map<String, Object?> data) {
    return WebDavServer(
      id: data['id'] as int?,
      title: data['title'] as String,
      url: data['url'] as String,
      root: data['root'] as String,
      auth: WebDavAuth.fromMap(jsonDecode(data['auth'] as String)),
      extra: jsonDecode(data['extra'] as String? ?? "null"),
    );
  }

  Map<String, Object?> toSqlite() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'root': root,
      'auth': jsonEncode(auth.toMap()),
      'extra': jsonEncode(extra),
    };
  }

  @override
  String toString() => toSqlite().toString();
}
