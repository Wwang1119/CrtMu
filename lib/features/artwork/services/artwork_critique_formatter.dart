import '../models/artwork_models.dart';

String formatArtworkCritiqueMessage(ArtworkAnalysisResult result) {
  final critique = result.artwork.critique;
  final buffer = StringBuffer()
    ..writeln(critique.summary)
    ..writeln()
    ..writeln('构图：${critique.scores.composition}')
    ..writeln('造型：${critique.scores.shape}')
    ..writeln('色彩：${critique.scores.color}')
    ..writeln('光影：${critique.scores.light}');

  if (critique.strengths.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('优点：${critique.strengths.join('、')}');
  }

  if (critique.weaknesses.isNotEmpty) {
    buffer.writeln('待加强：${critique.weaknesses.join('、')}');
  }

  if (critique.revisionSuggestions.isNotEmpty) {
    buffer.writeln('修改建议：');
    for (var index = 0; index < critique.revisionSuggestions.length; index++) {
      buffer.writeln('${index + 1}. ${critique.revisionSuggestions[index]}');
    }
  }

  if (critique.nextExercise.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('下一步练习：${critique.nextExercise}');
  }

  return buffer.toString().trim();
}
