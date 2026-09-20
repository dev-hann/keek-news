import 'package:equatable/equatable.dart';

enum MediaSaveFailureType {
  network,
  permission,
  canceled,
  inProgress,
  unexpected,
}

class MediaSaveFailure extends Equatable {
  const MediaSaveFailure(this.type, [this.detail]);

  final MediaSaveFailureType type;
  final String? detail;

  @override
  List<Object?> get props => [type, detail];

  @override
  String toString() =>
      'MediaSaveFailure($type${detail == null ? '' : ', $detail'})';
}
