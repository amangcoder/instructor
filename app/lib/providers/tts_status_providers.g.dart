// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_status_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$planTtsStatusHash() => r'f6a770ea2d1bdc12974a89fb027b531992a07a25';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Polls `GET /api/tts/status/:planId` with adaptive exponential backoff and
/// updates the local SQLite plan cache after every successful response.
///
/// ### Polling schedule
/// - First poll fires after a 2-second initial delay.
/// - Each subsequent delay is multiplied by 1.5, capped at 30 seconds.
/// - Polling stops automatically when a terminal state is received
///   ([completed], [partial], or [failed]) or after 10 minutes have elapsed.
///
/// ### Local cache
/// After each successful poll the `plans` Drift table row for [planId] is
/// updated with the latest `ttsStatus`, `ttsTotal`, and `ttsCompleted` values.
/// This keeps [watchUserPlans] streams reactive so the UI reflects current
/// progress without a full server refresh.
///
/// ### Auto-cancel
/// The provider has auto-dispose semantics (default for `@riverpod`). When the
/// last widget listener unsubscribes (e.g. the widget leaves the tree), Riverpod
/// disposes the provider and a cancellation flag causes the in-progress delay
/// loop to exit on the next iteration — the stream closes promptly.
///
/// ### Error handling
/// [PlanApiException]s during polling are logged and swallowed — the stream
/// stays open so transient network errors do not abort the progress indicator.
/// The 10-minute timeout is still enforced across errors.
///
/// Usage:
/// ```dart
/// final ttsStatus = ref.watch(planTtsStatusProvider('plan-uuid-1234'));
/// ttsStatus.when(
///   data: (status) => Text('TTS: ${status.status} (${status.completed}/${status.total})'),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, st) => Text('Error: $e'),
/// );
/// ```
///
/// Copied from [planTtsStatus].
@ProviderFor(planTtsStatus)
const planTtsStatusProvider = PlanTtsStatusFamily();

/// Polls `GET /api/tts/status/:planId` with adaptive exponential backoff and
/// updates the local SQLite plan cache after every successful response.
///
/// ### Polling schedule
/// - First poll fires after a 2-second initial delay.
/// - Each subsequent delay is multiplied by 1.5, capped at 30 seconds.
/// - Polling stops automatically when a terminal state is received
///   ([completed], [partial], or [failed]) or after 10 minutes have elapsed.
///
/// ### Local cache
/// After each successful poll the `plans` Drift table row for [planId] is
/// updated with the latest `ttsStatus`, `ttsTotal`, and `ttsCompleted` values.
/// This keeps [watchUserPlans] streams reactive so the UI reflects current
/// progress without a full server refresh.
///
/// ### Auto-cancel
/// The provider has auto-dispose semantics (default for `@riverpod`). When the
/// last widget listener unsubscribes (e.g. the widget leaves the tree), Riverpod
/// disposes the provider and a cancellation flag causes the in-progress delay
/// loop to exit on the next iteration — the stream closes promptly.
///
/// ### Error handling
/// [PlanApiException]s during polling are logged and swallowed — the stream
/// stays open so transient network errors do not abort the progress indicator.
/// The 10-minute timeout is still enforced across errors.
///
/// Usage:
/// ```dart
/// final ttsStatus = ref.watch(planTtsStatusProvider('plan-uuid-1234'));
/// ttsStatus.when(
///   data: (status) => Text('TTS: ${status.status} (${status.completed}/${status.total})'),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, st) => Text('Error: $e'),
/// );
/// ```
///
/// Copied from [planTtsStatus].
class PlanTtsStatusFamily extends Family<AsyncValue<TtsStatusInfo>> {
  /// Polls `GET /api/tts/status/:planId` with adaptive exponential backoff and
  /// updates the local SQLite plan cache after every successful response.
  ///
  /// ### Polling schedule
  /// - First poll fires after a 2-second initial delay.
  /// - Each subsequent delay is multiplied by 1.5, capped at 30 seconds.
  /// - Polling stops automatically when a terminal state is received
  ///   ([completed], [partial], or [failed]) or after 10 minutes have elapsed.
  ///
  /// ### Local cache
  /// After each successful poll the `plans` Drift table row for [planId] is
  /// updated with the latest `ttsStatus`, `ttsTotal`, and `ttsCompleted` values.
  /// This keeps [watchUserPlans] streams reactive so the UI reflects current
  /// progress without a full server refresh.
  ///
  /// ### Auto-cancel
  /// The provider has auto-dispose semantics (default for `@riverpod`). When the
  /// last widget listener unsubscribes (e.g. the widget leaves the tree), Riverpod
  /// disposes the provider and a cancellation flag causes the in-progress delay
  /// loop to exit on the next iteration — the stream closes promptly.
  ///
  /// ### Error handling
  /// [PlanApiException]s during polling are logged and swallowed — the stream
  /// stays open so transient network errors do not abort the progress indicator.
  /// The 10-minute timeout is still enforced across errors.
  ///
  /// Usage:
  /// ```dart
  /// final ttsStatus = ref.watch(planTtsStatusProvider('plan-uuid-1234'));
  /// ttsStatus.when(
  ///   data: (status) => Text('TTS: ${status.status} (${status.completed}/${status.total})'),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error: (e, st) => Text('Error: $e'),
  /// );
  /// ```
  ///
  /// Copied from [planTtsStatus].
  const PlanTtsStatusFamily();

  /// Polls `GET /api/tts/status/:planId` with adaptive exponential backoff and
  /// updates the local SQLite plan cache after every successful response.
  ///
  /// ### Polling schedule
  /// - First poll fires after a 2-second initial delay.
  /// - Each subsequent delay is multiplied by 1.5, capped at 30 seconds.
  /// - Polling stops automatically when a terminal state is received
  ///   ([completed], [partial], or [failed]) or after 10 minutes have elapsed.
  ///
  /// ### Local cache
  /// After each successful poll the `plans` Drift table row for [planId] is
  /// updated with the latest `ttsStatus`, `ttsTotal`, and `ttsCompleted` values.
  /// This keeps [watchUserPlans] streams reactive so the UI reflects current
  /// progress without a full server refresh.
  ///
  /// ### Auto-cancel
  /// The provider has auto-dispose semantics (default for `@riverpod`). When the
  /// last widget listener unsubscribes (e.g. the widget leaves the tree), Riverpod
  /// disposes the provider and a cancellation flag causes the in-progress delay
  /// loop to exit on the next iteration — the stream closes promptly.
  ///
  /// ### Error handling
  /// [PlanApiException]s during polling are logged and swallowed — the stream
  /// stays open so transient network errors do not abort the progress indicator.
  /// The 10-minute timeout is still enforced across errors.
  ///
  /// Usage:
  /// ```dart
  /// final ttsStatus = ref.watch(planTtsStatusProvider('plan-uuid-1234'));
  /// ttsStatus.when(
  ///   data: (status) => Text('TTS: ${status.status} (${status.completed}/${status.total})'),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error: (e, st) => Text('Error: $e'),
  /// );
  /// ```
  ///
  /// Copied from [planTtsStatus].
  PlanTtsStatusProvider call(
    String planId,
  ) {
    return PlanTtsStatusProvider(
      planId,
    );
  }

  @override
  PlanTtsStatusProvider getProviderOverride(
    covariant PlanTtsStatusProvider provider,
  ) {
    return call(
      provider.planId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'planTtsStatusProvider';
}

/// Polls `GET /api/tts/status/:planId` with adaptive exponential backoff and
/// updates the local SQLite plan cache after every successful response.
///
/// ### Polling schedule
/// - First poll fires after a 2-second initial delay.
/// - Each subsequent delay is multiplied by 1.5, capped at 30 seconds.
/// - Polling stops automatically when a terminal state is received
///   ([completed], [partial], or [failed]) or after 10 minutes have elapsed.
///
/// ### Local cache
/// After each successful poll the `plans` Drift table row for [planId] is
/// updated with the latest `ttsStatus`, `ttsTotal`, and `ttsCompleted` values.
/// This keeps [watchUserPlans] streams reactive so the UI reflects current
/// progress without a full server refresh.
///
/// ### Auto-cancel
/// The provider has auto-dispose semantics (default for `@riverpod`). When the
/// last widget listener unsubscribes (e.g. the widget leaves the tree), Riverpod
/// disposes the provider and a cancellation flag causes the in-progress delay
/// loop to exit on the next iteration — the stream closes promptly.
///
/// ### Error handling
/// [PlanApiException]s during polling are logged and swallowed — the stream
/// stays open so transient network errors do not abort the progress indicator.
/// The 10-minute timeout is still enforced across errors.
///
/// Usage:
/// ```dart
/// final ttsStatus = ref.watch(planTtsStatusProvider('plan-uuid-1234'));
/// ttsStatus.when(
///   data: (status) => Text('TTS: ${status.status} (${status.completed}/${status.total})'),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, st) => Text('Error: $e'),
/// );
/// ```
///
/// Copied from [planTtsStatus].
class PlanTtsStatusProvider extends AutoDisposeStreamProvider<TtsStatusInfo> {
  /// Polls `GET /api/tts/status/:planId` with adaptive exponential backoff and
  /// updates the local SQLite plan cache after every successful response.
  ///
  /// ### Polling schedule
  /// - First poll fires after a 2-second initial delay.
  /// - Each subsequent delay is multiplied by 1.5, capped at 30 seconds.
  /// - Polling stops automatically when a terminal state is received
  ///   ([completed], [partial], or [failed]) or after 10 minutes have elapsed.
  ///
  /// ### Local cache
  /// After each successful poll the `plans` Drift table row for [planId] is
  /// updated with the latest `ttsStatus`, `ttsTotal`, and `ttsCompleted` values.
  /// This keeps [watchUserPlans] streams reactive so the UI reflects current
  /// progress without a full server refresh.
  ///
  /// ### Auto-cancel
  /// The provider has auto-dispose semantics (default for `@riverpod`). When the
  /// last widget listener unsubscribes (e.g. the widget leaves the tree), Riverpod
  /// disposes the provider and a cancellation flag causes the in-progress delay
  /// loop to exit on the next iteration — the stream closes promptly.
  ///
  /// ### Error handling
  /// [PlanApiException]s during polling are logged and swallowed — the stream
  /// stays open so transient network errors do not abort the progress indicator.
  /// The 10-minute timeout is still enforced across errors.
  ///
  /// Usage:
  /// ```dart
  /// final ttsStatus = ref.watch(planTtsStatusProvider('plan-uuid-1234'));
  /// ttsStatus.when(
  ///   data: (status) => Text('TTS: ${status.status} (${status.completed}/${status.total})'),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error: (e, st) => Text('Error: $e'),
  /// );
  /// ```
  ///
  /// Copied from [planTtsStatus].
  PlanTtsStatusProvider(
    String planId,
  ) : this._internal(
          (ref) => planTtsStatus(
            ref as PlanTtsStatusRef,
            planId,
          ),
          from: planTtsStatusProvider,
          name: r'planTtsStatusProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$planTtsStatusHash,
          dependencies: PlanTtsStatusFamily._dependencies,
          allTransitiveDependencies:
              PlanTtsStatusFamily._allTransitiveDependencies,
          planId: planId,
        );

  PlanTtsStatusProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.planId,
  }) : super.internal();

  final String planId;

  @override
  Override overrideWith(
    Stream<TtsStatusInfo> Function(PlanTtsStatusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PlanTtsStatusProvider._internal(
        (ref) => create(ref as PlanTtsStatusRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        planId: planId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<TtsStatusInfo> createElement() {
    return _PlanTtsStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanTtsStatusProvider && other.planId == planId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, planId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PlanTtsStatusRef on AutoDisposeStreamProviderRef<TtsStatusInfo> {
  /// The parameter `planId` of this provider.
  String get planId;
}

class _PlanTtsStatusProviderElement
    extends AutoDisposeStreamProviderElement<TtsStatusInfo>
    with PlanTtsStatusRef {
  _PlanTtsStatusProviderElement(super.provider);

  @override
  String get planId => (origin as PlanTtsStatusProvider).planId;
}

String _$isTtsReadyHash() => r'e609ebd5c8ecea06d8bd339377d4685efc34f576';

/// Returns `true` when the GenAI TTS audio for [planId] is ready to play.
///
/// ### Check order
/// 1. **Local cache** — if the local SQLite plan row already has
///    `ttsStatus == 'completed'`, returns `true` immediately without starting
///    any network polling.  This is the fast path: no HTTP requests, no
///    subscriptions, instant result.
/// 2. **Live polling** — if the cached status is not yet `'completed'` (or the
///    plan hasn't loaded yet), falls back to watching [planTtsStatusProvider]
///    which polls `GET /api/tts/status/:planId` with adaptive exponential
///    backoff.  Returns `true` as soon as the first `'completed'` response
///    arrives from the server.
///
/// Returns `false` while:
/// - the plan is still loading from the local cache,
/// - TTS generation is still in progress (`pending` / `processing`),
/// - polling has not yet returned a `'completed'` status,
/// - the plan does not exist, or
/// - an API error occurred (the stream stays open but no `'completed'` value
///   has been received).
///
/// When the plan is already `'completed'` in the local cache, [isTtsReady]
/// does **not** subscribe to [planTtsStatusProvider] — polling never starts,
/// saving battery and network.
///
/// Usage:
/// ```dart
/// final ready = ref.watch(isTtsReadyProvider('plan-uuid-1234'));
/// if (ready) {
///   // safe to switch to GenAI TTS playback
/// }
/// ```
///
/// Copied from [isTtsReady].
@ProviderFor(isTtsReady)
const isTtsReadyProvider = IsTtsReadyFamily();

/// Returns `true` when the GenAI TTS audio for [planId] is ready to play.
///
/// ### Check order
/// 1. **Local cache** — if the local SQLite plan row already has
///    `ttsStatus == 'completed'`, returns `true` immediately without starting
///    any network polling.  This is the fast path: no HTTP requests, no
///    subscriptions, instant result.
/// 2. **Live polling** — if the cached status is not yet `'completed'` (or the
///    plan hasn't loaded yet), falls back to watching [planTtsStatusProvider]
///    which polls `GET /api/tts/status/:planId` with adaptive exponential
///    backoff.  Returns `true` as soon as the first `'completed'` response
///    arrives from the server.
///
/// Returns `false` while:
/// - the plan is still loading from the local cache,
/// - TTS generation is still in progress (`pending` / `processing`),
/// - polling has not yet returned a `'completed'` status,
/// - the plan does not exist, or
/// - an API error occurred (the stream stays open but no `'completed'` value
///   has been received).
///
/// When the plan is already `'completed'` in the local cache, [isTtsReady]
/// does **not** subscribe to [planTtsStatusProvider] — polling never starts,
/// saving battery and network.
///
/// Usage:
/// ```dart
/// final ready = ref.watch(isTtsReadyProvider('plan-uuid-1234'));
/// if (ready) {
///   // safe to switch to GenAI TTS playback
/// }
/// ```
///
/// Copied from [isTtsReady].
class IsTtsReadyFamily extends Family<bool> {
  /// Returns `true` when the GenAI TTS audio for [planId] is ready to play.
  ///
  /// ### Check order
  /// 1. **Local cache** — if the local SQLite plan row already has
  ///    `ttsStatus == 'completed'`, returns `true` immediately without starting
  ///    any network polling.  This is the fast path: no HTTP requests, no
  ///    subscriptions, instant result.
  /// 2. **Live polling** — if the cached status is not yet `'completed'` (or the
  ///    plan hasn't loaded yet), falls back to watching [planTtsStatusProvider]
  ///    which polls `GET /api/tts/status/:planId` with adaptive exponential
  ///    backoff.  Returns `true` as soon as the first `'completed'` response
  ///    arrives from the server.
  ///
  /// Returns `false` while:
  /// - the plan is still loading from the local cache,
  /// - TTS generation is still in progress (`pending` / `processing`),
  /// - polling has not yet returned a `'completed'` status,
  /// - the plan does not exist, or
  /// - an API error occurred (the stream stays open but no `'completed'` value
  ///   has been received).
  ///
  /// When the plan is already `'completed'` in the local cache, [isTtsReady]
  /// does **not** subscribe to [planTtsStatusProvider] — polling never starts,
  /// saving battery and network.
  ///
  /// Usage:
  /// ```dart
  /// final ready = ref.watch(isTtsReadyProvider('plan-uuid-1234'));
  /// if (ready) {
  ///   // safe to switch to GenAI TTS playback
  /// }
  /// ```
  ///
  /// Copied from [isTtsReady].
  const IsTtsReadyFamily();

  /// Returns `true` when the GenAI TTS audio for [planId] is ready to play.
  ///
  /// ### Check order
  /// 1. **Local cache** — if the local SQLite plan row already has
  ///    `ttsStatus == 'completed'`, returns `true` immediately without starting
  ///    any network polling.  This is the fast path: no HTTP requests, no
  ///    subscriptions, instant result.
  /// 2. **Live polling** — if the cached status is not yet `'completed'` (or the
  ///    plan hasn't loaded yet), falls back to watching [planTtsStatusProvider]
  ///    which polls `GET /api/tts/status/:planId` with adaptive exponential
  ///    backoff.  Returns `true` as soon as the first `'completed'` response
  ///    arrives from the server.
  ///
  /// Returns `false` while:
  /// - the plan is still loading from the local cache,
  /// - TTS generation is still in progress (`pending` / `processing`),
  /// - polling has not yet returned a `'completed'` status,
  /// - the plan does not exist, or
  /// - an API error occurred (the stream stays open but no `'completed'` value
  ///   has been received).
  ///
  /// When the plan is already `'completed'` in the local cache, [isTtsReady]
  /// does **not** subscribe to [planTtsStatusProvider] — polling never starts,
  /// saving battery and network.
  ///
  /// Usage:
  /// ```dart
  /// final ready = ref.watch(isTtsReadyProvider('plan-uuid-1234'));
  /// if (ready) {
  ///   // safe to switch to GenAI TTS playback
  /// }
  /// ```
  ///
  /// Copied from [isTtsReady].
  IsTtsReadyProvider call(
    String planId,
  ) {
    return IsTtsReadyProvider(
      planId,
    );
  }

  @override
  IsTtsReadyProvider getProviderOverride(
    covariant IsTtsReadyProvider provider,
  ) {
    return call(
      provider.planId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isTtsReadyProvider';
}

/// Returns `true` when the GenAI TTS audio for [planId] is ready to play.
///
/// ### Check order
/// 1. **Local cache** — if the local SQLite plan row already has
///    `ttsStatus == 'completed'`, returns `true` immediately without starting
///    any network polling.  This is the fast path: no HTTP requests, no
///    subscriptions, instant result.
/// 2. **Live polling** — if the cached status is not yet `'completed'` (or the
///    plan hasn't loaded yet), falls back to watching [planTtsStatusProvider]
///    which polls `GET /api/tts/status/:planId` with adaptive exponential
///    backoff.  Returns `true` as soon as the first `'completed'` response
///    arrives from the server.
///
/// Returns `false` while:
/// - the plan is still loading from the local cache,
/// - TTS generation is still in progress (`pending` / `processing`),
/// - polling has not yet returned a `'completed'` status,
/// - the plan does not exist, or
/// - an API error occurred (the stream stays open but no `'completed'` value
///   has been received).
///
/// When the plan is already `'completed'` in the local cache, [isTtsReady]
/// does **not** subscribe to [planTtsStatusProvider] — polling never starts,
/// saving battery and network.
///
/// Usage:
/// ```dart
/// final ready = ref.watch(isTtsReadyProvider('plan-uuid-1234'));
/// if (ready) {
///   // safe to switch to GenAI TTS playback
/// }
/// ```
///
/// Copied from [isTtsReady].
class IsTtsReadyProvider extends AutoDisposeProvider<bool> {
  /// Returns `true` when the GenAI TTS audio for [planId] is ready to play.
  ///
  /// ### Check order
  /// 1. **Local cache** — if the local SQLite plan row already has
  ///    `ttsStatus == 'completed'`, returns `true` immediately without starting
  ///    any network polling.  This is the fast path: no HTTP requests, no
  ///    subscriptions, instant result.
  /// 2. **Live polling** — if the cached status is not yet `'completed'` (or the
  ///    plan hasn't loaded yet), falls back to watching [planTtsStatusProvider]
  ///    which polls `GET /api/tts/status/:planId` with adaptive exponential
  ///    backoff.  Returns `true` as soon as the first `'completed'` response
  ///    arrives from the server.
  ///
  /// Returns `false` while:
  /// - the plan is still loading from the local cache,
  /// - TTS generation is still in progress (`pending` / `processing`),
  /// - polling has not yet returned a `'completed'` status,
  /// - the plan does not exist, or
  /// - an API error occurred (the stream stays open but no `'completed'` value
  ///   has been received).
  ///
  /// When the plan is already `'completed'` in the local cache, [isTtsReady]
  /// does **not** subscribe to [planTtsStatusProvider] — polling never starts,
  /// saving battery and network.
  ///
  /// Usage:
  /// ```dart
  /// final ready = ref.watch(isTtsReadyProvider('plan-uuid-1234'));
  /// if (ready) {
  ///   // safe to switch to GenAI TTS playback
  /// }
  /// ```
  ///
  /// Copied from [isTtsReady].
  IsTtsReadyProvider(
    String planId,
  ) : this._internal(
          (ref) => isTtsReady(
            ref as IsTtsReadyRef,
            planId,
          ),
          from: isTtsReadyProvider,
          name: r'isTtsReadyProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$isTtsReadyHash,
          dependencies: IsTtsReadyFamily._dependencies,
          allTransitiveDependencies:
              IsTtsReadyFamily._allTransitiveDependencies,
          planId: planId,
        );

  IsTtsReadyProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.planId,
  }) : super.internal();

  final String planId;

  @override
  Override overrideWith(
    bool Function(IsTtsReadyRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IsTtsReadyProvider._internal(
        (ref) => create(ref as IsTtsReadyRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        planId: planId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<bool> createElement() {
    return _IsTtsReadyProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsTtsReadyProvider && other.planId == planId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, planId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IsTtsReadyRef on AutoDisposeProviderRef<bool> {
  /// The parameter `planId` of this provider.
  String get planId;
}

class _IsTtsReadyProviderElement extends AutoDisposeProviderElement<bool>
    with IsTtsReadyRef {
  _IsTtsReadyProviderElement(super.provider);

  @override
  String get planId => (origin as IsTtsReadyProvider).planId;
}

String _$isFullyDownloadedHash() => r'30a6fc482e7f1d5930e55d051a1c23551db78ea9';

/// Returns `true` if every TTS audio file for [planId] is locally cached and
/// present on disk.
///
/// Delegates to [AudioDownloadService.isFullyDownloaded] which checks the
/// [TtsCacheTable] for each expected cache key **and** verifies the audio file
/// exists on disk.  A `false` result means either the plan has not been
/// activated yet, audio generation is still in progress, or one or more files
/// failed to download.
///
/// Returns `false` on any error (API failure, IO exception, etc.) — it never
/// throws.
///
/// Usage:
/// ```dart
/// final downloaded = ref.watch(isFullyDownloadedProvider('plan-uuid-1234'));
/// downloaded.when(
///   data: (ready) => ready
///       ? const Icon(Icons.check_circle)
///       : const CircularProgressIndicator(),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, _) => const Icon(Icons.error),
/// );
/// ```
///
/// Copied from [isFullyDownloaded].
@ProviderFor(isFullyDownloaded)
const isFullyDownloadedProvider = IsFullyDownloadedFamily();

/// Returns `true` if every TTS audio file for [planId] is locally cached and
/// present on disk.
///
/// Delegates to [AudioDownloadService.isFullyDownloaded] which checks the
/// [TtsCacheTable] for each expected cache key **and** verifies the audio file
/// exists on disk.  A `false` result means either the plan has not been
/// activated yet, audio generation is still in progress, or one or more files
/// failed to download.
///
/// Returns `false` on any error (API failure, IO exception, etc.) — it never
/// throws.
///
/// Usage:
/// ```dart
/// final downloaded = ref.watch(isFullyDownloadedProvider('plan-uuid-1234'));
/// downloaded.when(
///   data: (ready) => ready
///       ? const Icon(Icons.check_circle)
///       : const CircularProgressIndicator(),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, _) => const Icon(Icons.error),
/// );
/// ```
///
/// Copied from [isFullyDownloaded].
class IsFullyDownloadedFamily extends Family<AsyncValue<bool>> {
  /// Returns `true` if every TTS audio file for [planId] is locally cached and
  /// present on disk.
  ///
  /// Delegates to [AudioDownloadService.isFullyDownloaded] which checks the
  /// [TtsCacheTable] for each expected cache key **and** verifies the audio file
  /// exists on disk.  A `false` result means either the plan has not been
  /// activated yet, audio generation is still in progress, or one or more files
  /// failed to download.
  ///
  /// Returns `false` on any error (API failure, IO exception, etc.) — it never
  /// throws.
  ///
  /// Usage:
  /// ```dart
  /// final downloaded = ref.watch(isFullyDownloadedProvider('plan-uuid-1234'));
  /// downloaded.when(
  ///   data: (ready) => ready
  ///       ? const Icon(Icons.check_circle)
  ///       : const CircularProgressIndicator(),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error: (e, _) => const Icon(Icons.error),
  /// );
  /// ```
  ///
  /// Copied from [isFullyDownloaded].
  const IsFullyDownloadedFamily();

  /// Returns `true` if every TTS audio file for [planId] is locally cached and
  /// present on disk.
  ///
  /// Delegates to [AudioDownloadService.isFullyDownloaded] which checks the
  /// [TtsCacheTable] for each expected cache key **and** verifies the audio file
  /// exists on disk.  A `false` result means either the plan has not been
  /// activated yet, audio generation is still in progress, or one or more files
  /// failed to download.
  ///
  /// Returns `false` on any error (API failure, IO exception, etc.) — it never
  /// throws.
  ///
  /// Usage:
  /// ```dart
  /// final downloaded = ref.watch(isFullyDownloadedProvider('plan-uuid-1234'));
  /// downloaded.when(
  ///   data: (ready) => ready
  ///       ? const Icon(Icons.check_circle)
  ///       : const CircularProgressIndicator(),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error: (e, _) => const Icon(Icons.error),
  /// );
  /// ```
  ///
  /// Copied from [isFullyDownloaded].
  IsFullyDownloadedProvider call(
    String planId,
  ) {
    return IsFullyDownloadedProvider(
      planId,
    );
  }

  @override
  IsFullyDownloadedProvider getProviderOverride(
    covariant IsFullyDownloadedProvider provider,
  ) {
    return call(
      provider.planId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isFullyDownloadedProvider';
}

/// Returns `true` if every TTS audio file for [planId] is locally cached and
/// present on disk.
///
/// Delegates to [AudioDownloadService.isFullyDownloaded] which checks the
/// [TtsCacheTable] for each expected cache key **and** verifies the audio file
/// exists on disk.  A `false` result means either the plan has not been
/// activated yet, audio generation is still in progress, or one or more files
/// failed to download.
///
/// Returns `false` on any error (API failure, IO exception, etc.) — it never
/// throws.
///
/// Usage:
/// ```dart
/// final downloaded = ref.watch(isFullyDownloadedProvider('plan-uuid-1234'));
/// downloaded.when(
///   data: (ready) => ready
///       ? const Icon(Icons.check_circle)
///       : const CircularProgressIndicator(),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, _) => const Icon(Icons.error),
/// );
/// ```
///
/// Copied from [isFullyDownloaded].
class IsFullyDownloadedProvider extends AutoDisposeFutureProvider<bool> {
  /// Returns `true` if every TTS audio file for [planId] is locally cached and
  /// present on disk.
  ///
  /// Delegates to [AudioDownloadService.isFullyDownloaded] which checks the
  /// [TtsCacheTable] for each expected cache key **and** verifies the audio file
  /// exists on disk.  A `false` result means either the plan has not been
  /// activated yet, audio generation is still in progress, or one or more files
  /// failed to download.
  ///
  /// Returns `false` on any error (API failure, IO exception, etc.) — it never
  /// throws.
  ///
  /// Usage:
  /// ```dart
  /// final downloaded = ref.watch(isFullyDownloadedProvider('plan-uuid-1234'));
  /// downloaded.when(
  ///   data: (ready) => ready
  ///       ? const Icon(Icons.check_circle)
  ///       : const CircularProgressIndicator(),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error: (e, _) => const Icon(Icons.error),
  /// );
  /// ```
  ///
  /// Copied from [isFullyDownloaded].
  IsFullyDownloadedProvider(
    String planId,
  ) : this._internal(
          (ref) => isFullyDownloaded(
            ref as IsFullyDownloadedRef,
            planId,
          ),
          from: isFullyDownloadedProvider,
          name: r'isFullyDownloadedProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$isFullyDownloadedHash,
          dependencies: IsFullyDownloadedFamily._dependencies,
          allTransitiveDependencies:
              IsFullyDownloadedFamily._allTransitiveDependencies,
          planId: planId,
        );

  IsFullyDownloadedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.planId,
  }) : super.internal();

  final String planId;

  @override
  Override overrideWith(
    FutureOr<bool> Function(IsFullyDownloadedRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IsFullyDownloadedProvider._internal(
        (ref) => create(ref as IsFullyDownloadedRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        planId: planId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _IsFullyDownloadedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsFullyDownloadedProvider && other.planId == planId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, planId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IsFullyDownloadedRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `planId` of this provider.
  String get planId;
}

class _IsFullyDownloadedProviderElement
    extends AutoDisposeFutureProviderElement<bool> with IsFullyDownloadedRef {
  _IsFullyDownloadedProviderElement(super.provider);

  @override
  String get planId => (origin as IsFullyDownloadedProvider).planId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
