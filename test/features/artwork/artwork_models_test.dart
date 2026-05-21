import 'package:art_assistant/features/artwork/models/artwork_models.dart';
import 'package:art_assistant/features/artwork/services/artwork_critique_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Artwork models', () {
    test('parse upload response payload', () {
      final upload = BackendUpload.fromJson({
        'id': 'upload-1',
        'localUrl': 'http://127.0.0.1:3000/uploads/a.jpg',
      });

      expect(upload.id, 'upload-1');
      expect(upload.localUrl, contains('/uploads/a.jpg'));
    });

    test('parse artwork analysis response payload', () {
      final result = ArtworkAnalysisResult.fromJson({
        'ok': true,
        'provider': 'mock',
        'artwork': {
          'id': 'artwork-1',
          'generation': {'status': 'locked'},
          'critique': {
            'summary': '整体关系清楚。',
            'scores': {
              'composition': 80,
              'shape': 70.5,
              'color': '66',
              'light': null,
            },
            'strengths': ['主体明确'],
            'weaknesses': ['明暗还可加强'],
            'revisionSuggestions': ['先做黑白灰练习'],
            'nextExercise': '15 分钟重画。',
          },
        },
      });

      expect(result.artwork.id, 'artwork-1');
      expect(result.artwork.generationStatus, 'locked');
      expect(result.artwork.critique.scores.composition, 80);
      expect(result.artwork.critique.scores.shape, 71);
      expect(result.artwork.critique.scores.color, 66);
      expect(result.artwork.critique.scores.light, 0);
    });

    test('parse reference generation response payload', () {
      final result = ReferenceGenerationResult.fromJson({
        'ok': true,
        'result': {
          'imageUrl': 'https://example.com/reference.png',
          'note': '参考图已生成。',
        },
      });

      expect(result.imageUrl, endsWith('reference.png'));
      expect(result.note, '参考图已生成。');
    });

    test('format critique as chat message', () {
      final message = formatArtworkCritiqueMessage(
        ArtworkAnalysisResult.fromJson({
          'artwork': {
            'id': 'artwork-1',
            'generation': {'status': 'locked'},
            'critique': {
              'summary': '整体关系清楚。',
              'scores': {
                'composition': 80,
                'shape': 70,
                'color': 66,
                'light': 60,
              },
              'strengths': ['主体明确'],
              'weaknesses': ['明暗还可加强'],
              'revisionSuggestions': ['先做黑白灰练习'],
              'nextExercise': '15 分钟重画。',
            },
          },
        }),
      );

      expect(message, contains('构图：80'));
      expect(message, contains('优点：主体明确'));
      expect(message, contains('1. 先做黑白灰练习'));
    });
  });
}
