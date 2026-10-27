/// Local, content-free eligibility. A request is never a review-submission fact.
class RatingState {
  const RatingState({this.successfulTasks = 0, this.lastOfferedAt});
  static const taskThreshold = 3;
  static const cooldown = Duration(days: 30);
  final int successfulTasks;
  final DateTime? lastOfferedAt;
  bool eligible(DateTime now) =>
      successfulTasks >= taskThreshold &&
      (lastOfferedAt == null ||
          now.toUtc().difference(lastOfferedAt!) >= cooldown);
  RatingState successfulTask() => RatingState(
    successfulTasks: (successfulTasks + 1).clamp(0, taskThreshold),
    lastOfferedAt: lastOfferedAt,
  );
  RatingState offered(DateTime now) => RatingState(lastOfferedAt: now.toUtc());
  Map<String, dynamic> toJson() => {
    'version': 1,
    'successfulTasks': successfulTasks,
    if (lastOfferedAt != null)
      'lastOfferedAt': lastOfferedAt!.toUtc().toIso8601String(),
  };
  factory RatingState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['successfulTasks'] is! int ||
        (json['successfulTasks'] as int) < 0 ||
        (json['successfulTasks'] as int) > taskThreshold) {
      throw const FormatException('Invalid rating eligibility state');
    }
    return RatingState(
      successfulTasks: json['successfulTasks'] as int,
      lastOfferedAt: json['lastOfferedAt'] == null
          ? null
          : DateTime.parse(json['lastOfferedAt'] as String).toUtc(),
    );
  }
}

abstract interface class RatingStore {
  Future<RatingState> load();
  Future<void> save(RatingState state);
}

abstract interface class RatingPlatform {
  Future<bool> isAvailable();
  Future<void> requestReview();
}
