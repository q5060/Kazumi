import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/media.dart';
import 'package:path/path.dart' as p;

class JimakuEntry {
  const JimakuEntry({required this.id, required this.name, this.japaneseName});

  factory JimakuEntry.fromJson(Map<String, dynamic> json) => JimakuEntry(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    japaneseName: json['japanese_name'] as String?,
  );

  final int id;
  final String name;
  final String? japaneseName;

  String get label {
    final japanese = japaneseName?.trim() ?? '';
    return japanese.isEmpty || japanese == name ? name : '$japanese ($name)';
  }
}

class JimakuFile {
  const JimakuFile({required this.name, required this.url, required this.size});

  factory JimakuFile.fromJson(Map<String, dynamic> json) => JimakuFile(
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    size: json['size'] as int? ?? 0,
  );

  final String name;
  final String url;
  final int size;
}

class JimakuException implements Exception {
  const JimakuException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lower is better. SRT comes first because the player renders subtitles as
/// plain text, and ASS releases often add sign/karaoke lines that clutter it.
const Map<String, int> _subtitleExtensionRank = {
  'srt': 0,
  'ass': 1,
  'ssa': 1,
  'vtt': 2,
};

int? jimakuSubtitleRank(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return _subtitleExtensionRank[fileName.substring(dot + 1).toLowerCase()];
}

/// Playable subtitle files sorted by preference; archives are dropped.
List<JimakuFile> sortJimakuSubtitleFiles(Iterable<JimakuFile> files) {
  final playable = files
      .where((f) => jimakuSubtitleRank(f.name) != null)
      .toList();
  playable.sort((a, b) {
    final byRank = jimakuSubtitleRank(
      a.name,
    )!.compareTo(jimakuSubtitleRank(b.name)!);
    return byRank != 0 ? byRank : a.name.compareTo(b.name);
  });
  return playable;
}

/// Prefers the entry whose Japanese title matches exactly, then the first hit.
JimakuEntry? pickJimakuEntry(List<JimakuEntry> entries, String animeName) {
  if (entries.isEmpty) return null;
  final target = animeName.trim();
  for (final entry in entries) {
    if (entry.japaneseName?.trim() == target || entry.name.trim() == target) {
      return entry;
    }
  }
  return entries.first;
}

class JimakuSubtitleService {
  JimakuSubtitleService._();

  static final JimakuSubtitleService instance = JimakuSubtitleService._();

  static const String _baseUrl = 'https://jimaku.cc/api';

  final Map<String, List<JimakuEntry>> _searchCache = {};

  String get apiKey => GStorage.getSetting(SettingsKeys.jimakuApiKey).trim();

  bool get hasApiKey => apiKey.isNotEmpty;

  Options get _options => Options(
    headers: {
      'Authorization': apiKey,
      'user-agent': 'Kazumi (https://github.com/Predidit/Kazumi)',
    },
  );

  Future<List<JimakuEntry>> searchEntries(String animeName) async {
    final query = animeName.trim();
    if (query.isEmpty) return const [];
    final cached = _searchCache[query];
    if (cached != null) return cached;
    final data = await _get('/entries/search', {'query': query, 'anime': true});
    final entries = [
      for (final item in data as List) JimakuEntry.fromJson(item),
    ];
    _searchCache[query] = entries;
    return entries;
  }

  /// Returns every file of the entry when [episode] is null.
  Future<List<JimakuFile>> listFiles(int entryId, {int? episode}) async {
    final data = await _get('/entries/$entryId/files', {
      if (episode != null && episode > 0) 'episode': episode,
    });
    return [for (final item in data as List) JimakuFile.fromJson(item)];
  }

  Future<String> download(JimakuFile file) async {
    final directory = Directory(
      p.join(await getPlayerTempPath(), 'jimaku_subtitles'),
    );
    await directory.create(recursive: true);
    final safeName = file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final savePath = p.join(directory.path, safeName);
    try {
      await DioFactory.apiDio.download(file.url, savePath, options: _options);
    } on DioException catch (e) {
      throw _mapError(e);
    }
    return savePath;
  }

  Future<dynamic> _get(String path, Map<String, dynamic> query) async {
    if (!hasApiKey) {
      throw const JimakuException('请先在播放设置中填写 Jimaku API Key');
    }
    try {
      final response = await DioFactory.apiDio.get(
        '$_baseUrl$path',
        queryParameters: query,
        options: _options,
      );
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  JimakuException _mapError(DioException e) {
    return switch (e.response?.statusCode) {
      401 => const JimakuException('Jimaku API Key 无效'),
      429 => const JimakuException('Jimaku 请求过于频繁，请稍后再试'),
      _ => JimakuException('连接 Jimaku 失败：${e.message ?? e.type.name}'),
    };
  }
}
