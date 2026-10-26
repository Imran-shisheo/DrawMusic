import '../../../creative_document/document.dart';

enum ExportFormat { midi, wav, mp4, png }

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
    this.framesPerSecond,
  });
  final String path, mime, name, projectId;
  final int revision;
  final int? width, height, framesPerSecond;
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
    int fps = 30,
    void Function(double)? onProgress,
  });
}

/// Still-image output is independent of score compilation and playback state.
abstract interface class ImageExportPort {
  Future<ExportArtifact> exportImage(
    ProjectDocument document,
    ExportCancellation cancellation, {
    int width = 1080,
    bool transparentBackground = false,
    void Function(double)? onProgress,
  });
}

String readableExportName(String title, String extension) {
  final name = title.replaceAll(RegExp(r'[/\\\x00-\x1f\x7f]'), '_').trim();
  return '${name.isEmpty ? 'Drawing' : name}.$extension';
}
