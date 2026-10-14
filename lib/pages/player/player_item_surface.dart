import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:kazumi/pages/player/player_controller.dart';

const _subtitleStyle = TextStyle(
  color: Colors.pink,
  fontSize: 48.0,
  decoration: TextDecoration.none,
  fontWeight: FontWeight.bold,
  shadows: [
    Shadow(
      offset: Offset(1.0, 1.0),
      blurRadius: 3.0,
      color: Color.fromARGB(255, 255, 255, 255),
    ),
    Shadow(
      offset: Offset(-1.0, -1.0),
      blurRadius: 3.0,
      color: Color.fromARGB(125, 255, 255, 255),
    ),
  ],
);

class PlayerItemSurface extends StatefulWidget {
  const PlayerItemSurface({
    super.key,
    required this.playerController,
  });

  final PlayerController playerController;

  @override
  State<PlayerItemSurface> createState() => _PlayerItemSurfaceState();
}

class _PlayerItemSurfaceState extends State<PlayerItemSurface> {
  @override
  Widget build(BuildContext context) {
    final playerController = widget.playerController;
    return Observer(builder: (context) {
      if (playerController.playback.loading ||
          playerController.playback.videoController == null) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final aspectRatioMode = playerController.panel.aspectRatioMode;
      final mask = playerController.subtitles.mask;
      final player = playerController.playback.mediaPlayer;
      Widget video = Video(
        controller: playerController.playback.videoController!,
        controls: NoVideoControls,
        pauseUponEnteringBackgroundMode: false,
        fit: aspectRatioMode.fit,
        subtitleViewConfiguration: SubtitleViewConfiguration(
          visible: mask <= 0,
          style: _subtitleStyle.copyWith(
            background: Paint()..color = Colors.transparent,
          ),
          textAlign: TextAlign.center,
          padding: const EdgeInsets.all(24.0),
        ),
      );
      if (mask > 0 && player != null) {
        video = Stack(children: [
          Positioned.fill(child: video),
          Positioned.fill(
            child: _SubtitleMask(
              player: player,
              fraction: mask,
              fit: aspectRatioMode.fit,
              videoSize: Size(
                playerController.debug.playerWidth.toDouble(),
                playerController.debug.playerHeight.toDouble(),
              ),
            ),
          ),
        ]);
      }

      final frameAspectRatio = aspectRatioMode.frameAspectRatio;
      if (frameAspectRatio == null) {
        return video;
      }
      return AspectRatio(
        aspectRatio: frameAspectRatio,
        child: video,
      );
    });
  }
}

/// Covers subtitles burned into the bottom of the picture and shows the
/// player's own subtitles inside the covered band instead.
class _SubtitleMask extends StatelessWidget {
  const _SubtitleMask({
    required this.player,
    required this.fraction,
    required this.fit,
    required this.videoSize,
  });

  final Player player;
  final double fraction;
  final BoxFit fit;
  final Size videoSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final box = Offset.zero & constraints.biggest;
      final source = videoSize.isEmpty ? const Size(16, 9) : videoSize;
      final picture = Alignment.center
          .inscribe(applyBoxFit(fit, source, box.size).destination, box)
          .intersect(box);
      final height = picture.height * fraction;
      return Stack(children: [
        Positioned(
          left: picture.left,
          width: picture.width,
          top: picture.bottom - height,
          height: height,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.6),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: height * 0.08,
                  ),
                  child: _MaskSubtitleText(
                    player: player,
                    fontSize: (height * 0.34).clamp(12.0, 48.0),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

class _MaskSubtitleText extends StatelessWidget {
  const _MaskSubtitleText({required this.player, required this.fontSize});

  final Player player;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: player.stream.subtitle,
      initialData: player.state.subtitle,
      builder: (context, snapshot) {
        final text = [
          for (final line in snapshot.data ?? const <String>[])
            if (line.trim().isNotEmpty) line.trim(),
        ].join('\n');
        if (text.isEmpty) return const SizedBox.expand();
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: _subtitleStyle.copyWith(fontSize: fontSize),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
