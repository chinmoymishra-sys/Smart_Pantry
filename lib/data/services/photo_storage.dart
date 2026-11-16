import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies user-selected images into app-managed storage so they survive
/// beyond temporary picker paths. Only local file paths are persisted.
abstract interface class PhotoStorage {
  Future<String> importPhoto(String sourcePath);
  Future<void> delete(String path);
}

class LocalPhotoStorage implements PhotoStorage {
  LocalPhotoStorage({Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;
  static const _uuid = Uuid();

  Future<Directory> _photosDir() async {
    final dir = Directory(p.join((await _baseDir()).path, 'photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String> importPhoto(String sourcePath) async {
    final dir = await _photosDir();
    if (p.isWithin(dir.path, sourcePath)) return sourcePath;
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(sourcePath).copy(target);
    return target;
  }

  @override
  Future<void> delete(String path) async {
    // Only delete files we manage; never touch bundled assets or other paths.
    final dir = await _photosDir();
    if (!p.isWithin(dir.path, path)) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
