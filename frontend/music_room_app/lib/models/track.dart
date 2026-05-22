// * model for a single song, in the future i would like to add mode Offine
class Track {
  final String id;
  final String providerId;
  final String provider;
  final String title;
  final String artist;
  final int durationMs;
  final String? artworkUrl;
  final int score;
  final String? position;

  Track({
    required this.id,
    required this.providerId,
    this.provider = 'spotify',
    required this.title,
    required this.artist,
    required this.durationMs,
    this.artworkUrl,
    this.score = 0,
    this.position,
  });

  // * Helper getter — converts ms to seconds for display
  int get durationSeconds => durationMs ~/ 1000;

  String get durationString {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      provider: json['provider'] as String? ?? 'spotify',
      title: json['title'] as String,
      artist: json['artist'] as String,
      durationMs: json['durationMs'] as int,
      artworkUrl: json['artworkUrl'] as String?,
      score: json['score'] as int? ?? 0,
      position: json['position'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'providerId': providerId,
    'provider': provider,
    'title': title,
    'artist': artist,
    'durationMs': durationMs,
    if (artworkUrl != null) 'artworkUrl': artworkUrl,
    'score': score,
    if (position != null) 'position': position,
  };

  Track copyWith({int? score, String? position}) {
    return Track(
      id: id,
      providerId: providerId,
      provider: provider,
      title: title,
      artist: artist,
      durationMs: durationMs,
      artworkUrl: artworkUrl,
      score: score ?? this.score,
      position: position ?? this.position,
    );
  }
}
