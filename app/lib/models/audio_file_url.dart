/// Model representing a pre-signed S3 URL for a TTS audio file, paired with
/// its local cache key so callers can register the download in [TtsCacheTable].
class AudioFileUrl {
  const AudioFileUrl({
    required this.cacheKey,
    required this.url,
  });

  /// Identifies the audio file in the local TTS cache (e.g. a hash of
  /// plan-id + step-id + voice settings).
  final String cacheKey;

  /// Pre-signed S3 URL from which the audio file can be downloaded.
  /// URLs are short-lived and must be used promptly after retrieval.
  final String url;

  factory AudioFileUrl.fromJson(Map<String, dynamic> json) {
    return AudioFileUrl(
      cacheKey: json['cacheKey']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'cacheKey': cacheKey,
        'url': url,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioFileUrl &&
          runtimeType == other.runtimeType &&
          cacheKey == other.cacheKey &&
          url == other.url;

  @override
  int get hashCode => Object.hash(cacheKey, url);

  @override
  String toString() => 'AudioFileUrl(cacheKey: $cacheKey, url: $url)';
}
