import 'package:in_app_review/in_app_review.dart';

import '../domain/rating_state.dart';

/// Actual platform APIs, with no synthetic success or unverified store URL.
class NativeRatingPlatform implements RatingPlatform {
  NativeRatingPlatform() : _review = InAppReview.instance;
  final InAppReview _review;
  @override
  Future<bool> isAvailable() => _review.isAvailable();
  @override
  Future<void> requestReview() => _review.requestReview();
}
