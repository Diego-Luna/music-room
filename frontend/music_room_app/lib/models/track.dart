class Track {
  final String id;
  final String title;
  final String artist;
  final int durationSeconds;
  final String? albumArtUrl;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    this.albumArtUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      durationSeconds: json['durationSeconds'] as int,
      albumArtUrl: json['albumArtUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'durationSeconds': durationSeconds,
    'albumArtUrl': albumArtUrl,
  };

  String get albumArt => albumArtUrl ?? '';

  String get durationString {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
