import '../../../creative_document/document.dart';
import '../../export/domain/export_port.dart';

class LibraryExport {
  const LibraryExport({
    required this.id,
    required this.artifact,
    required this.createdAt,
    required this.bytes,
    required this.available,
    this.preview,
    this.deletedAt,
    this.legacy = false,
  });
  final String id;
  final ExportArtifact artifact;
  final DateTime createdAt;
  final int bytes;
  final bool available, legacy;
  final ProjectDocument? preview;
  final DateTime? deletedAt;
}

class ExportListing {
  const ExportListing(this.entries, {this.detailFailures = 0});
  final List<LibraryExport> entries;
  final int detailFailures;
}

abstract interface class ExportLibrary {
  Future<ExportListing> list();
  Future<void> record(ExportArtifact artifact, ProjectDocument document);
  Future<void> rename(String id, String title);
  Future<void> remove(String id);
  Future<void> restore(String id);
}

class PublicExportCopy {
  const PublicExportCopy(this.uri, this.destination, this.bytes);
  final String uri, destination;
  final int bytes;
}

abstract interface class ExportFileActions {
  Future<void> open(ExportArtifact artifact);
  Future<PublicExportCopy?> save(ExportArtifact artifact);
}
