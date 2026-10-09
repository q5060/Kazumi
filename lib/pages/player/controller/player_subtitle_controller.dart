// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mobx/mobx.dart';

part 'player_subtitle_controller.g.dart';

const List<String> subtitleFileExtensions = ['srt', 'ass', 'ssa', 'vtt'];

bool isSubtitleFileName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  return subtitleFileExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// Drops mpv's `auto` / `no` pseudo tracks, which are not real streams.
List<SubtitleTrack> selectableSubtitleTracks(Iterable<SubtitleTrack> tracks) =>
    tracks.where((t) => t.id != 'auto' && t.id != 'no').toList();

String subtitleTrackLabel(SubtitleTrack track) {
  final title = track.title?.trim() ?? '';
  final language = track.language?.trim() ?? '';
  if (title.isNotEmpty && language.isNotEmpty && title != language) {
    return '$title ($language)';
  }
  if (title.isNotEmpty) return title;
  if (language.isNotEmpty) return language;
  return '轨道 ${track.id}';
}

/// External tracks are selected by URI, while mpv lists them by numeric id,
/// so they can only be matched back through the title passed to `sub-add`.
bool isSubtitleTrackSelected(SubtitleTrack track, SubtitleTrack current) {
  if (current.uri || current.data) {
    return current.title != null && track.title == current.title;
  }
  return track.id == current.id;
}

class PlayerSubtitleController = _PlayerSubtitleController
    with _$PlayerSubtitleController;

abstract class _PlayerSubtitleController with Store {
  @observable
  List<SubtitleTrack> tracks = const [];
  @observable
  SubtitleTrack current = SubtitleTrack.auto();

  bool get disabled => current.id == 'no';

  Player? _player;
  StreamSubscription<Tracks>? _tracksSubscription;
  StreamSubscription<Track>? _trackSubscription;

  Future<void> setup(
    Player player, {
    required bool Function(Player player) isCurrentPlayer,
  }) async {
    await cancel();
    if (!isCurrentPlayer(player)) return;
    _player = player;
    tracks = selectableSubtitleTracks(player.state.tracks.subtitle);
    current = player.state.track.subtitle;
    _tracksSubscription = player.stream.tracks.listen((event) {
      tracks = selectableSubtitleTracks(event.subtitle);
    });
    _trackSubscription = player.stream.track.listen((event) {
      current = event.subtitle;
    });
  }

  Future<void> cancel() async {
    // Detach fields before awaiting so a new player cannot lose its listeners.
    final tracksSubscription = _tracksSubscription;
    final trackSubscription = _trackSubscription;
    _tracksSubscription = null;
    _trackSubscription = null;
    _player = null;
    tracks = const [];
    current = SubtitleTrack.auto();
    await tracksSubscription?.cancel();
    await trackSubscription?.cancel();
  }

  Future<void> select(SubtitleTrack track) => _setTrack(_player, track);

  Future<void> disable() => _setTrack(_player, SubtitleTrack.no());

  Future<void> loadExternal() async {
    final player = _player;
    if (player == null) return;
    // Android has no MIME type for srt/ass, so a custom filter hides them.
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择字幕文件',
        type: Platform.isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: Platform.isAndroid ? null : subtitleFileExtensions,
        lockParentWindow: true,
      );
    } catch (e) {
      KazumiLogger()
          .w('PlayerSubtitleController: failed to pick file', error: e);
      KazumiDialog.showToast(message: '无法打开文件选择器');
      return;
    }
    if (result == null) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null || !isSubtitleFileName(file.name)) {
      KazumiDialog.showToast(
          message: '仅支持 ${subtitleFileExtensions.join(' / ')} 字幕文件');
      return;
    }
    if (!identical(_player, player)) return;
    await _setTrack(player, SubtitleTrack.uri(path, title: file.name));
  }

  Future<void> _setTrack(Player? player, SubtitleTrack track) async {
    if (player == null) return;
    try {
      await player.setSubtitleTrack(track);
    } catch (e) {
      KazumiLogger()
          .w('PlayerSubtitleController: failed to set subtitle', error: e);
      KazumiDialog.showToast(message: '字幕加载失败');
    }
  }
}
