import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/services/download/japanese_subtitle_cache.dart';
import 'package:path/path.dart' as p;

class _UnusedRepository implements IDownloadRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

DownloadEpisode _episode(int number, String name) => DownloadEpisode(
      number,
      name,
      0,
      DownloadStatus.completed,
      1,
      0,
      0,
      '',
      '',
      '',
      null,
      '',
      0,
      '',
    );

void main() {
  group('jimakuEpisodeNumber', () {
    test('uses the number in the episode title', () {
      expect(jimakuEpisodeNumber(_episode(3, '第05集')), 5);
    });

    test('falls back to the download position', () {
      expect(jimakuEpisodeNumber(_episode(3, '正片')), 3);
    });
  });

  group('JapaneseSubtitleCache.findIn', () {
    late Directory dir;
    final cache = JapaneseSubtitleCache(_UnusedRepository());

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('kazumi_subtitle_test');
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('returns null without a download directory or subtitles', () async {
      expect(await cache.findIn(''), isNull);
      expect(await cache.findIn(dir.path), isNull);
    });

    test('prefers srt and ignores other files', () async {
      final subtitles = Directory(p.join(dir.path, 'subtitles_ja'));
      await subtitles.create();
      for (final name in ['b.ass', 'a.srt', 'notes.txt']) {
        await File(p.join(subtitles.path, name)).writeAsString('');
      }
      expect(await cache.findIn(dir.path), p.join(subtitles.path, 'a.srt'));
    });
  });
}
