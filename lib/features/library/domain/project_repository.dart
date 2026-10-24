import '../../../creative_document/document.dart';

class ProjectListing {
  const ProjectListing(this.projects, this.failures);
  final List<ProjectDocument> projects;
  final List<String> failures;
}

abstract interface class ProjectRepository {
  Future<void> save(ProjectDocument document);
  Future<ProjectDocument> load(String id);
  Future<ProjectListing> list();
}
