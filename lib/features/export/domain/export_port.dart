import '../../../creative_document/document.dart';

enum ExportFormat { midi, wav }

class ExportCancellation {
  bool cancelled = false;
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
    this.revision,
  );
  final String path, mime, name, projectId;
  final int revision;
}

abstract interface class ExportPort {
  Future<ExportArtifact> export(
    ProjectDocument document,
    ExportFormat format,
    ExportCancellation cancellation,
  );
}
