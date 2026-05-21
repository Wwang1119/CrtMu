class BackendUpload {
  final String id;
  final String localUrl;

  const BackendUpload({required this.id, required this.localUrl});

  factory BackendUpload.fromJson(Map<String, dynamic> json) {
    return BackendUpload(
      id: json['id']?.toString() ?? '',
      localUrl: json['localUrl']?.toString() ?? '',
    );
  }
}

class ArtworkAnalysisResult {
  final AnalyzedArtwork artwork;

  const ArtworkAnalysisResult({required this.artwork});

  factory ArtworkAnalysisResult.fromJson(Map<String, dynamic> json) {
    final artworkJson = json['artwork'];
    if (artworkJson is! Map) {
      throw const FormatException('Artwork analysis response missing artwork.');
    }

    return ArtworkAnalysisResult(
      artwork: AnalyzedArtwork.fromJson(artworkJson.cast<String, dynamic>()),
    );
  }
}

class ReferenceGenerationResult {
  final String imageUrl;
  final String note;

  const ReferenceGenerationResult({
    required this.imageUrl,
    required this.note,
  });

  factory ReferenceGenerationResult.fromJson(Map<String, dynamic> json) {
    final resultJson = json['result'];
    if (resultJson is! Map) {
      throw const FormatException(
        'Reference generation response missing result.',
      );
    }

    return ReferenceGenerationResult(
      imageUrl: resultJson['imageUrl']?.toString() ?? '',
      note: resultJson['note']?.toString() ?? '参考图已生成。',
    );
  }
}

class AnalyzedArtwork {
  final String id;
  final String generationStatus;
  final ArtworkCritique critique;

  const AnalyzedArtwork({
    required this.id,
    required this.generationStatus,
    required this.critique,
  });

  factory AnalyzedArtwork.fromJson(Map<String, dynamic> json) {
    final critiqueJson = json['critique'];
    final generationJson = json['generation'];
    if (critiqueJson is! Map) {
      throw const FormatException('Artwork payload missing critique.');
    }

    return AnalyzedArtwork(
      id: json['id']?.toString() ?? '',
      generationStatus: generationJson is Map
          ? generationJson['status']?.toString() ?? ''
          : '',
      critique: ArtworkCritique.fromJson(critiqueJson.cast<String, dynamic>()),
    );
  }
}

class ArtworkCritique {
  final String summary;
  final ArtworkScores scores;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> revisionSuggestions;
  final String nextExercise;

  const ArtworkCritique({
    required this.summary,
    required this.scores,
    required this.strengths,
    required this.weaknesses,
    required this.revisionSuggestions,
    required this.nextExercise,
  });

  factory ArtworkCritique.fromJson(Map<String, dynamic> json) {
    final scoresJson = json['scores'];
    if (scoresJson is! Map) {
      throw const FormatException('Critique payload missing scores.');
    }

    List<String> parseStringList(dynamic value) {
      if (value is! List) return const <String>[];
      return value.map((item) => item.toString()).toList();
    }

    return ArtworkCritique(
      summary: json['summary']?.toString() ?? '',
      scores: ArtworkScores.fromJson(scoresJson.cast<String, dynamic>()),
      strengths: parseStringList(json['strengths']),
      weaknesses: parseStringList(json['weaknesses']),
      revisionSuggestions: parseStringList(json['revisionSuggestions']),
      nextExercise: json['nextExercise']?.toString() ?? '',
    );
  }
}

class ArtworkScores {
  final int composition;
  final int shape;
  final int color;
  final int light;

  const ArtworkScores({
    required this.composition,
    required this.shape,
    required this.color,
    required this.light,
  });

  factory ArtworkScores.fromJson(Map<String, dynamic> json) {
    int parseScore(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ArtworkScores(
      composition: parseScore(json['composition']),
      shape: parseScore(json['shape']),
      color: parseScore(json['color']),
      light: parseScore(json['light']),
    );
  }
}
