import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/features/rating/application/rating_coordinator.dart';
import 'package:scribblesong/features/rating/data/file_rating_store.dart';
import 'package:scribblesong/features/rating/domain/rating_state.dart';

class MemoryRatingStore implements RatingStore {
  RatingState state = const RatingState();
  bool failRead = false, failSave = false;
  @override
  Future<RatingState> load() async {
    if (failRead) throw const FormatException('Corrupt');
    return state;
  }

  @override
  Future<void> save(RatingState value) async {
    if (failSave) throw const FileSystemException('No space');
    state = value;
  }
}

class TestRatingPlatform implements RatingPlatform {
  bool available = true, failRequest = false;
  int availabilityChecks = 0, requests = 0;
  void Function()? onAvailability;
  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    onAvailability?.call();
    return available;
  }

  @override
  Future<void> requestReview() async {
    requests++;
    if (failRequest) throw StateError('Native review unavailable');
  }
}

void main() {
  test('three successful tasks required; dismissal persists cooldown before prompt', () async {
    var now = DateTime.utc(2026, 10, 26);
    final store = MemoryRatingStore();
    final platform = TestRatingPlatform();
    final coordinator = RatingCoordinator(store, platform, clock: () => now);
    var prompts = 0;
    Future<bool> dismiss() async {
      prompts++;
      expect(store.state.lastOfferedAt, now);
      return false;
    }

    for (var i = 0; i < 2; i++) {
      expect(await coordinator.recordSuccessfulTask(), isTrue);
      expect(
        await coordinator.offerIfEligible(isSafe: () => true, confirm: dismiss),
        RatingOutcome.notEligible,
      );
    }
    expect(platform.availabilityChecks, 0);
    await coordinator.recordSuccessfulTask();
    expect(
      await coordinator.offerIfEligible(isSafe: () => true, confirm: dismiss),
      RatingOutcome.dismissed,
    );
    expect(prompts, 1);
    expect(platform.requests, 0);
    final reopened = RatingCoordinator(store, platform, clock: () => now);
    for (var i = 0; i < 3; i++) {
      await reopened.recordSuccessfulTask();
    }
    now = now.add(const Duration(days: 29, hours: 23));
    expect(
      await reopened.offerIfEligible(isSafe: () => true, confirm: dismiss),
      RatingOutcome.notEligible,
    );
    now = now.add(const Duration(hours: 1));
    expect(
      await reopened.offerIfEligible(isSafe: () => true, confirm: dismiss),
      RatingOutcome.dismissed,
    );
    expect(prompts, 2);
  });

  test(
    'availability false and unsafe creative state never open either prompt',
    () async {
      final store = MemoryRatingStore()
        ..state = const RatingState(successfulTasks: 3);
      final platform = TestRatingPlatform()..available = false;
      final coordinator = RatingCoordinator(store, platform);
      Future<bool> forbidden() async =>
          throw StateError('Prompt should not appear');
      expect(
        await coordinator.offerIfEligible(
          isSafe: () => false,
          confirm: forbidden,
        ),
        RatingOutcome.busy,
      );
      expect(platform.availabilityChecks, 0);
      expect(
        await coordinator.offerIfEligible(
          isSafe: () => true,
          confirm: forbidden,
        ),
        RatingOutcome.unavailable,
      );
      expect(store.state.lastOfferedAt, isNull);
      expect(platform.requests, 0);
      var safe = true;
      platform.available = true;
      platform.onAvailability = () => safe = false;
      expect(
        await coordinator.offerIfEligible(
          isSafe: () => safe,
          confirm: forbidden,
        ),
        RatingOutcome.busy,
      );
      expect(store.state.lastOfferedAt, isNull);
    },
  );

  test(
    'failed persistence suppresses optional prompts and leaves original state',
    () async {
      final store = MemoryRatingStore()..failSave = true;
      final platform = TestRatingPlatform();
      final coordinator = RatingCoordinator(store, platform);
      expect(await coordinator.recordSuccessfulTask(), isFalse);
      expect(store.state.successfulTasks, 0);
      store.state = const RatingState(successfulTasks: 3);
      var prompts = 0;
      expect(
        await coordinator.offerIfEligible(
          isSafe: () => true,
          confirm: () async {
            prompts++;
            return true;
          },
        ),
        RatingOutcome.storageUnavailable,
      );
      expect(prompts, 0);
      expect(platform.requests, 0);
      expect(store.state.lastOfferedAt, isNull);
      store.failRead = true;
      expect(
        await coordinator.offerIfEligible(
          isSafe: () => true,
          confirm: () async => true,
        ),
        RatingOutcome.storageUnavailable,
      );
    },
  );

  test('safety rechecks before native launch; native failure never implies submission', () async {
    final store = MemoryRatingStore()
      ..state = const RatingState(successfulTasks: 3);
    final platform = TestRatingPlatform();
    final coordinator = RatingCoordinator(store, platform);
    var safe = true;
    expect(
      await coordinator.offerIfEligible(
        isSafe: () => safe,
        confirm: () async {
          safe = false;
          return true;
        },
      ),
      RatingOutcome.busy,
    );
    expect(platform.requests, 0);
    expect(store.state.lastOfferedAt, isNotNull);
    store.state = const RatingState(successfulTasks: 3);
    platform.failRequest = true;
    expect(
      await coordinator.offerIfEligible(
        isSafe: () => true,
        confirm: () async => true,
      ),
      RatingOutcome.failed,
    );
    expect(platform.requests, 1);
    expect(store.state.lastOfferedAt, isNotNull);
    expect(
      await coordinator.offerIfEligible(
        isSafe: () => true,
        confirm: () async => true,
      ),
      RatingOutcome.notEligible,
    );
  });

  test(
    'concurrent triggers request at most once; success is only a request fact',
    () async {
      final store = MemoryRatingStore()
        ..state = const RatingState(successfulTasks: 3);
      final platform = TestRatingPlatform();
      final coordinator = RatingCoordinator(store, platform);
      final ready = Completer<void>();
      final choice = Completer<bool>();
      final first = coordinator.offerIfEligible(
        isSafe: () => true,
        confirm: () {
          ready.complete();
          return choice.future;
        },
      );
      await ready.future;
      expect(
        await coordinator.offerIfEligible(
          isSafe: () => true,
          confirm: () async => true,
        ),
        RatingOutcome.busy,
      );
      choice.complete(true);
      expect(await first, RatingOutcome.requested);
      expect(platform.requests, 1);
    },
  );

  test('clock rollback and invalid eligibility values fail closed', () {
    final state = RatingState(
      successfulTasks: 3,
      lastOfferedAt: DateTime.utc(2026, 10, 26),
    );
    expect(state.eligible(DateTime.utc(2026, 9)), isFalse);
    expect(state.eligible(DateTime.utc(2026, 11, 25)), isTrue);
    expect(
      () => RatingState.fromJson({'version': 1, 'successfulTasks': 4}),
      throwsFormatException,
    );
    expect(
      () => RatingState.fromJson({'version': 9, 'successfulTasks': 3}),
      throwsFormatException,
    );
  });

  test('file store atomically reopens and preserves corrupt bytes without re-prompt', () async {
    final root = await Directory.systemTemp.createTemp('drawmusic-rating-');
    addTearDown(() => root.delete(recursive: true));
    final store = FileRatingStore(root);
    expect((await store.load()).successfulTasks, 0);
    final date = DateTime.utc(2026, 10, 26);
    await store.save(RatingState(successfulTasks: 2, lastOfferedAt: date));
    final reopened = await FileRatingStore(root).load();
    expect(reopened.successfulTasks, 2);
    expect(reopened.lastOfferedAt, date);
    expect(await File('${store.file.path}.tmp').exists(), isFalse);
    await store.file.writeAsString('original corrupt bytes', flush: true);
    final coordinator = RatingCoordinator(store, TestRatingPlatform());
    expect(await coordinator.recordSuccessfulTask(), isFalse);
    expect(
      await coordinator.offerIfEligible(
        isSafe: () => true,
        confirm: () async => true,
      ),
      RatingOutcome.storageUnavailable,
    );
    expect(await store.file.readAsString(), 'original corrupt bytes');
    await expectLater(store.save(const RatingState()), throwsFormatException);
  });
}
