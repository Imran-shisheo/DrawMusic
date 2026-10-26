import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/file_rating_store.dart';
import '../data/native_rating_platform.dart';
import 'rating_coordinator.dart';

final ratingCoordinatorProvider = FutureProvider<RatingCoordinator>((
  ref,
) async {
  final root = await getApplicationSupportDirectory();
  return RatingCoordinator(
    FileRatingStore(Directory('${root.path}/rating')),
    NativeRatingPlatform(),
  );
});
