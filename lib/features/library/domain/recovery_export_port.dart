/// Optional capability for retaining undecodable project bytes. This is not an
/// editable-project, audio or image export; sharing remains an explicit action.
abstract interface class RecoveryExportPort {
  Future<String> exportRecoveryData(String projectId);
}
