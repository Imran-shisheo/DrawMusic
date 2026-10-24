import '../../../creative_document/document.dart';

class ProjectLoad {
  const ProjectLoad(this.document, {this.recovered = false});
  final ProjectDocument document;
  final bool recovered;
}

class ProjectListing {
  const ProjectListing(
    this.projects,
    this.failures, {
    this.recoveredIds = const [],
  });
  final List<ProjectDocument> projects;
  final List<String> failures, recoveredIds;
}

abstract interface class ProjectRepository {
  Future<void> save(ProjectDocument document);
  Future<ProjectDocument> load(String id);
  Future<ProjectLoad> open(String id);
  Future<ProjectListing> list();
  Future<void> rename(String id, String title);
  Future<ProjectDocument> duplicate(String id);
  Future<void> softDelete(String id);
  Future<void> restore(String id);
}
