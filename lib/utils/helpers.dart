import 'dart:io';

import 'package:flutter/material.dart';

const defaultThumbnailImage = AssetImage('assets/images/open-book-512.png');

const supportedContentTypes = [
  'application', // application/pdf, application/epub+zip
  'audio', // audio/aac, audio/mp3, audio/m4a, audio/m4b, ...
  'image', // image/jpeg, image/png, image/webp, image/bmp, image/gif
  'video', // video/x-msvideo, video/mp4, video/mpeg,
];

IconData getMimeIcon(ContentType? type) {
  if (type != null) {
    switch (type.primaryType) {
      case 'application':
        if (type.subType == 'pdf') {
          return Icons.picture_as_pdf_rounded;
        } else {
          // return Icons.smartphone_rounded;
          return Icons.library_books_rounded;
        }
      case 'audio':
        return Icons.headphones_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'text':
        return Icons.description_rounded;
      default:
        return Icons.question_mark_rounded;
    }
  }
  return Icons.question_mark_rounded;
}

IconData getSourceIcon(String url) {
  if (url.contains('librivox')) {
    return Icons.local_library_rounded;
  } else if (url.contains('archive.org')) {
    return Icons.account_balance_rounded;
  } else if (url.startsWith('file:///')) {
    return Icons.storage_rounded;
  } else {
    return Icons.cloud_rounded;
  }
}

String durationToString(Duration? duration) {
  final durString = duration.toString();
  // return durString.substring(0, durString.lastIndexOf('.'));
  return duration != null
      ? durString.substring(0, durString.lastIndexOf('.'))
      : '';
}

String secsToHhMmSs(int? seconds) {
  if (seconds != null && seconds > 0) {
    final h = seconds ~/ 3600;
    final m = (seconds - h * 3600) ~/ 60;
    final s = (seconds - h * 3600 - m * 60);

    return h > 0
        ? "${h.toString()}h ${m.toString().padLeft(2, '0')}m"
        : m > 0
        ? "${m.toString()}m ${s.toString().padLeft(2, '0')}s"
        : "${s.toString()}s";
  }
  return "??m";
}

//
// NOTE: this is not legitimate mime types
//
ContentType? getContentTypeFromUriString(String? uri) {
  if (uri != null) {
    final ext = uri.split('?')[0].split('.').reversed.elementAt(0);
    // print('uri:$uri, extention: $ext');
    if (['pdf', 'epub'].contains(ext)) {
      return ContentType('application', ext);
    } else if ([
      'aac',
      'm4a',
      'm4b',
      'mp3',
      'ogg',
      'wav',
      'weba',
    ].contains(ext)) {
      return ContentType('audio', ext);
    } else if ([
      'bmp',
      'gif',
      'jpeg',
      'jpg',
      'png',
      'svg',
      'webp',
    ].contains(ext)) {
      return ContentType('image', ext);
    } else if (['mp4', 'mpeg', 'webm'].contains(ext)) {
      return ContentType('video', ext);
    } else if (['html', 'txt'].contains(ext)) {
      return ContentType('text', ext);
    }
  }
  return null;
}
