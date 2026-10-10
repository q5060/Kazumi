import 'package:flutter/material.dart';

import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/material_bottom_sheet.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/services/player/jimaku_subtitle_service.dart';

Future<JimakuFile?> showJimakuSubtitleSheet(
  BuildContext context, {
  required String animeName,
  required int episode,
}) {
  return showAdaptiveBottomSheet<JimakuFile>(
    context: context,
    builder: (context) =>
        _JimakuSubtitleSheet(animeName: animeName, episode: episode),
  );
}

class _JimakuSubtitleSheet extends StatefulWidget {
  const _JimakuSubtitleSheet({required this.animeName, required this.episode});

  final String animeName;
  final int episode;

  @override
  State<_JimakuSubtitleSheet> createState() => _JimakuSubtitleSheetState();
}

class _JimakuSubtitleSheetState extends State<_JimakuSubtitleSheet> {
  final JimakuSubtitleService _service = JimakuSubtitleService.instance;

  List<JimakuEntry> _entries = const [];
  JimakuEntry? _entry;
  List<JimakuFile> _files = const [];
  bool _allEpisodes = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final entries = await _service.searchEntries(widget.animeName);
      if (!mounted) return;
      _entries = entries;
      final entry = pickJimakuEntry(entries, widget.animeName);
      if (entry == null) {
        setState(() {
          _loading = false;
          _error = 'Jimaku 上没有找到「${widget.animeName}」';
        });
        return;
      }
      await _loadFiles(entry);
    } on JimakuException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _loadFiles(JimakuEntry entry, {bool? allEpisodes}) async {
    final all = allEpisodes ?? _allEpisodes;
    setState(() {
      _entry = entry;
      _allEpisodes = all;
      _loading = true;
      _error = null;
    });
    try {
      final files = await _service.listFiles(
        entry.id,
        episode: all ? null : widget.episode,
      );
      if (!mounted) return;
      setState(() {
        _files = sortJimakuSubtitleFiles(files);
        _loading = false;
      });
    } on JimakuException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MaterialBottomSheetHeader(
          title: '搜索日文字幕',
          onClose: () => Navigator.of(context).pop(),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: materialBottomSheetContentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entry != null)
                  SplitListGroup(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.movie_outlined),
                        title: Text(entry.label),
                        subtitle: Text(
                          _entries.length > 1
                              ? '共 ${_entries.length} 个结果，点击切换'
                              : 'Jimaku 条目',
                        ),
                        onTap: _entries.length > 1 ? _chooseEntry : null,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.list_rounded),
                        title: const Text('显示全部集数'),
                        subtitle: Text(
                          _allEpisodes
                              ? '列出这个条目的所有字幕文件'
                              : '只列出第 ${widget.episode} 集',
                        ),
                        value: _allEpisodes,
                        onChanged: (value) =>
                            _loadFiles(entry, allEpisodes: value),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                _buildBody(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = _error;
    if (error != null || _files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          error ?? '没有可用的字幕文件，可以打开「显示全部集数」再找找',
          textAlign: TextAlign.center,
        ),
      );
    }
    return SplitListGroup(
      children: [
        for (final file in _files)
          ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: Text(file.name),
            subtitle: Text('${(file.size / 1024).toStringAsFixed(1)} KB'),
            onTap: () => Navigator.of(context).pop(file),
          ),
      ],
    );
  }

  Future<void> _chooseEntry() async {
    final chosen = await showDialog<JimakuEntry>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择条目'),
        children: [
          for (final entry in _entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(entry),
              child: Text(entry.label),
            ),
        ],
      ),
    );
    if (chosen != null && mounted) {
      await _loadFiles(chosen);
    }
  }
}
