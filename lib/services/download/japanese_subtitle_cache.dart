import 'dart:io';

import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/repositories/download_repository.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/player/jimaku_subtitle_service.dart';
import 'package:kazumi/utils/media.dart';
import 'package:path/path.dart' as p;

/// Episode number used to search Jimaku: the number in the episode title,
/// falling back to its position like the danmaku lookup does.
int jimakuEpisodeNumber(DownloadEpisode episode) {
  final parsed = extractEpisodeNumber(episode.episodeName);
  return parsed > 0 ? parsed : episode.episodeNumber;
}

/// Keeps Japanese subtitles inside each episode's download directory, so
/// they work offline and are deleted together with the episode.
class JapaneseSubtitleCache {
  JapaneseSubtitleCache(this._repository);

  final IDownloadRepository _repository;

  static const String _directoryName = 'subtitles_ja';

  Future<String?> find(int bangumiId, String pluginName, int episodeNumber) {
    final episode = _repository.getEpisode(
      bangumiId,
      pluginName,
      episodeNumber,
    );
    return findIn(episode?.downloadDirectory ?? '');
  }

  Future<String?> findIn(String downloadDirectory) async {
    if (downloadDirectory.isEmpty) return null;
    final directory = Directory(p.join(downloadDirectory, _directoryName));
    if (!await directory.exists()) return null;
    final files = await directory
        .list()
        .where((e) => e is File && jimakuSubtitleRank(e.path) != null)
        .map((e) => e.path)
        .toList();
    if (files.isEmpty) return null;
    files.sort((a, b) {
      final byRank = jimakuSubtitleRank(a)!.compareTo(jimakuSubtitleRank(b)!);
      return byRank != 0 ? byRank : a.compareTo(b);
    });
    return files.first;
  }

  /// Downloads the episode's subtitle from Jimaku into its download
  /// directory. Returns null when Jimaku has none; throws [JimakuException]
  /// on API or network errors.
  Future<String?> fetch(String recordKey, int episodeNumber) async {
    final record = _repository.getRecord(recordKey);
    final episode = record?.episodes[episodeNumber];
    if (record == null ||
        episode == null ||
        episode.downloadDirectory.isEmpty) {
      return null;
    }
    final animeName = await _searchName(record);
    return JimakuSubtitleService.instance.fetchEpisodeSubtitle(
      animeName,
      jimakuEpisodeNumber(episode),
      directory: p.join(episode.downloadDirectory, _directoryName),
    );
  }

  /// Records created before the Japanese title was stored only have the
  /// Chinese one, which Jimaku cannot match, so it is looked up once.
  Future<String> _searchName(DownloadRecord record) async {
    if (record.bangumiOriginalName.isNotEmpty) {
      return record.bangumiOriginalName;
    }
    final item = await BangumiApi.getBangumiInfoByID(record.bangumiId);
    final name = item?.name.trim() ?? '';
    if (name.isEmpty) return record.bangumiName;
    final fresh = _repository.getRecord(record.key);
    if (fresh != null) {
      fresh.bangumiOriginalName = name;
      try {
        await _repository.putRecord(fresh);
      } catch (e) {
        KazumiLogger()
            .w('JapaneseSubtitleCache: failed to save original name', error: e);
      }
    }
    return name;
  }
}
