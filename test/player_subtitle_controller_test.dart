import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/controller/player_subtitle_controller.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  group('selectableSubtitleTracks', () {
    test('drops auto and no pseudo tracks', () {
      final tracks = selectableSubtitleTracks([
        SubtitleTrack.auto(),
        SubtitleTrack.no(),
        SubtitleTrack('1', 'Chinese', 'chi'),
        SubtitleTrack('2', null, 'jpn'),
      ]);

      expect(tracks.map((t) => t.id), ['1', '2']);
    });
  });

  group('subtitleTrackLabel', () {
    test('combines title and language', () {
      expect(subtitleTrackLabel(SubtitleTrack('1', '简体中文', 'chi')),
          '简体中文 (chi)');
    });

    test('falls back to language, then id', () {
      expect(subtitleTrackLabel(SubtitleTrack('2', null, 'jpn')), 'jpn');
      expect(subtitleTrackLabel(SubtitleTrack('3', ' ', null)), '轨道 3');
    });

    test('does not repeat identical title and language', () {
      expect(subtitleTrackLabel(SubtitleTrack('4', 'jpn', 'jpn')), 'jpn');
    });
  });

  group('isSubtitleTrackSelected', () {
    test('matches embedded tracks by id', () {
      final current = SubtitleTrack('2', null, 'jpn');
      final japanese = SubtitleTrack('2', null, 'jpn');
      final chinese = SubtitleTrack('1', null, 'chi');

      expect(isSubtitleTrackSelected(japanese, current), isTrue);
      expect(isSubtitleTrackSelected(chinese, current), isFalse);
    });

    test('matches external tracks by the title passed to sub-add', () {
      final current =
          SubtitleTrack.uri('/tmp/ep01.ja.ass', title: 'ep01.ja.ass');
      final external = SubtitleTrack('3', 'ep01.ja.ass', null);
      final embedded = SubtitleTrack('1', 'Chinese', 'chi');

      expect(isSubtitleTrackSelected(external, current), isTrue);
      expect(isSubtitleTrackSelected(embedded, current), isFalse);
    });
  });

  group('isSubtitleFileName', () {
    test('accepts supported extensions case-insensitively', () {
      expect(isSubtitleFileName('ep01.ja.ASS'), isTrue);
      expect(isSubtitleFileName('ep01.srt'), isTrue);
      expect(isSubtitleFileName('ep01.vtt'), isTrue);
    });

    test('rejects other files', () {
      expect(isSubtitleFileName('ep01.mp4'), isFalse);
      expect(isSubtitleFileName('subtitle'), isFalse);
    });
  });
}
