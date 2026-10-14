// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_subtitle_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerSubtitleController on _PlayerSubtitleController, Store {
  late final _$tracksAtom = Atom(
    name: '_PlayerSubtitleController.tracks',
    context: context,
  );

  @override
  List<SubtitleTrack> get tracks {
    _$tracksAtom.reportRead();
    return super.tracks;
  }

  @override
  set tracks(List<SubtitleTrack> value) {
    _$tracksAtom.reportWrite(value, super.tracks, () {
      super.tracks = value;
    });
  }

  late final _$currentAtom = Atom(
    name: '_PlayerSubtitleController.current',
    context: context,
  );

  @override
  SubtitleTrack get current {
    _$currentAtom.reportRead();
    return super.current;
  }

  @override
  set current(SubtitleTrack value) {
    _$currentAtom.reportWrite(value, super.current, () {
      super.current = value;
    });
  }

  late final _$delayAtom = Atom(
    name: '_PlayerSubtitleController.delay',
    context: context,
  );

  @override
  double get delay {
    _$delayAtom.reportRead();
    return super.delay;
  }

  @override
  set delay(double value) {
    _$delayAtom.reportWrite(value, super.delay, () {
      super.delay = value;
    });
  }

  late final _$maskAtom = Atom(
    name: '_PlayerSubtitleController.mask',
    context: context,
  );

  @override
  double get mask {
    _$maskAtom.reportRead();
    return super.mask;
  }

  @override
  set mask(double value) {
    _$maskAtom.reportWrite(value, super.mask, () {
      super.mask = value;
    });
  }

  @override
  String toString() {
    return '''
tracks: ${tracks},
current: ${current},
delay: ${delay},
mask: ${mask}
    ''';
  }
}
