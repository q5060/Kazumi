import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/controller/player_subtitle_controller.dart';
import 'package:kazumi/services/player/jimaku_subtitle_service.dart';

JimakuFile _file(String name) => JimakuFile(name: name, url: '', size: 0);

void main() {
  group('sortJimakuSubtitleFiles', () {
    test('drops archives and prefers srt over ass over vtt', () {
      final files = sortJimakuSubtitleFiles([
        _file('season.zip'),
        _file('ep01.vtt'),
        _file('ep01.ass'),
        _file('ep01.SRT'),
        _file('notes.txt'),
      ]);

      expect(files.map((f) => f.name), ['ep01.SRT', 'ep01.ass', 'ep01.vtt']);
    });

    test('orders files of the same type by name', () {
      final files = sortJimakuSubtitleFiles([_file('b.srt'), _file('a.srt')]);

      expect(files.map((f) => f.name), ['a.srt', 'b.srt']);
    });
  });

  group('pickJimakuEntry', () {
    const first = JimakuEntry(
      id: 1,
      name: 'Yuru Camp',
      japaneseName: 'ゆるキャン△ SEASON2',
    );
    const exact = JimakuEntry(id: 2, name: 'Yuru Camp', japaneseName: 'ゆるキャン△');

    test('prefers an exact Japanese title match', () {
      expect(pickJimakuEntry([first, exact], 'ゆるキャン△')?.id, 2);
    });

    test('falls back to the first result', () {
      expect(pickJimakuEntry([first, exact], '別の作品')?.id, 1);
    });

    test('returns null when nothing was found', () {
      expect(pickJimakuEntry([], 'ゆるキャン△'), isNull);
    });
  });

  test('parses API JSON', () {
    final entry = JimakuEntry.fromJson({
      'id': 7,
      'name': 'Sousou no Frieren',
      'japanese_name': '葬送のフリーレン',
    });
    final file = JimakuFile.fromJson({
      'name': 'ep01.srt',
      'url': 'https://jimaku.cc/x',
      'size': 2048,
    });

    expect(entry.label, '葬送のフリーレン (Sousou no Frieren)');
    expect(file.size, 2048);
  });

  test('formatSubtitleDelay shows a sign for positive values', () {
    expect(formatSubtitleDelay(1.5), '+1.5 秒');
    expect(formatSubtitleDelay(-0.5), '-0.5 秒');
  });
}
