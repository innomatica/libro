import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  Directory? _rootDir;
  // ignore: unused_field
  final _logger = Logger('StorageService');

  Future<Directory> _getDocDir() async {
    _rootDir ??= await getApplicationDocumentsDirectory();
    return _rootDir!;
  }

  Future<Uri> getUri(String dirname, String filename) async {
    final root = await _getDocDir();
    return Uri.file('${root.path}/$dirname/$filename');
  }

  Future<File> getFile(String dirname, String filename) async {
    final root = await _getDocDir();
    return File('${root.path}/$dirname/$filename');
  }

  Future<Directory> getDirectory(String dirname) async {
    final root = await _getDocDir();
    return Directory('${root.path}/$dirname');
  }

  Future<File> createFile(String dirname, String filename) async {
    final root = await _getDocDir();
    final file = File('${root.path}/$dirname/$filename');
    file.createSync(recursive: true);
    return file;
  }

  Future deleteFile(String dirname, String filename) async {
    final root = await _getDocDir();
    final file = File('${root.path}/$dirname/$filename');
    if (file.existsSync()) file.deleteSync();
  }

  Future<bool> fileExists(String dirname, String filename) async {
    final root = await _getDocDir();
    final file = File('${root.path}/$dirname/$filename');
    return file.exists();
  }

  Future deleteDirectory(String dirname) async {
    final root = await _getDocDir();
    final dir = Directory('${root.path}/$dirname');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
