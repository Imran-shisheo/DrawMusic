import '../../../creative_document/document.dart';

enum ExportFormat { midi, wav, mp4 }

class ExportCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>[];
  bool get cancelled => _cancelled;
  set cancelled(bool value) {
    if (value && !_cancelled) {
      _cancelled = true;
      for (final listener in List.of(_listeners)) {
        listener();
      }
    }
  }

  void Function() onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void check() {
    if (cancelled) throw const ExportCancelled();
  }
}

class ExportCancelled implements Exception {
  const ExportCancelled();
}

class ExportArtifact {
  const ExportArtifact(
    this.path,
    this.mime,
    this.name,
    this.projectId,
    this.revision, {
    this.width,
    this.height,
    this.durationSeconds,
  });
  final String path, mime, name, projectId;
  final int revision;
  final int? width, height;
  final double? durationSeconds;
}

abstract interface class ExportPort {
  Future<ExportArtifact> export(
    ProjectDocument document,
    ExportFormat format,
    ExportCancellation cancellation,
  );
}

abstract interface class VideoExportPort {
  Future<ExportArtifact> exportVideo(
    ProjectDocument document,
    ExportCancellation cancellation, {
    int width = 1080,
    void Function(double)? onProgress,
  });
}
