import 'package:flutter_test/flutter_test.dart';
import 'package:safesphere/services/route_safety_ml_engine.dart';

void main() {
  group('Route Safety Machine Learning & NLP Sentiment Tests', () {
    test('1. FeedbackSentimentNLP accurately classifies positive commentary', () {
      const text = 'Extremely safe road, well-lit street with active police patrol!';
      final sentiment = FeedbackSentimentNLP.analyzeSentiment(text);
      expect(sentiment, greaterThan(0.5), reason: 'Positive commentary should yield positive sentiment score');
      print('  ✓ Positive NLP Sentiment Score: $sentiment');
    });

    test('2. FeedbackSentimentNLP accurately classifies negative commentary', () {
      const text = 'Dark isolated street, poor lighting and scary suspicious people.';
      final sentiment = FeedbackSentimentNLP.analyzeSentiment(text);
      expect(sentiment, lessThan(-0.5), reason: 'Negative commentary should yield negative sentiment score');
      print('  ✓ Negative NLP Sentiment Score: $sentiment');
    });

    test('3. Dynamic User Feedback reduces route safety score when negative feedback is submitted', () {
      const startLat = 13.0827;
      const startLng = 80.2707;
      const endLat = 13.0890;
      const endLng = 80.2780;

      // Initial prediction before negative feedback
      final initialPred = RouteSafetyMLEngine.predictSafetyScore(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
      );
      final initialScore = initialPred['score'] as int;

      // Submit negative user feedback at route location
      RouteSafetyMLEngine.processUserFeedback(
        rating: 1.0,
        tags: ['Poor lighting', 'Isolated street', 'Suspicious activity'],
        comments: 'Very unsafe dark street with scary suspicious activity.',
        lat: endLat,
        lng: endLng,
      );

      // Re-evaluate prediction after negative user feedback
      final updatedPred = RouteSafetyMLEngine.predictSafetyScore(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
      );
      final updatedScore = updatedPred['score'] as int;

      expect(updatedScore, lessThan(initialScore), reason: 'Negative user feedback must lower the ML safety score');
      print('  ✓ ML Dynamic Feedback Integration Verified:');
      print('    - Initial Safety Score: $initialScore% (${initialPred['level']})');
      print('    - Updated Safety Score after user feedback: $updatedScore% (${updatedPred['level']})');
      print('    - Feedbacks Analyzed: ${updatedPred['ml_metrics']['feedback_count']}');
    });

    test('4. Dynamic User Feedback increases route safety score when positive feedback is submitted', () {
      const startLat = 11.0168;
      const startLng = 76.9558;
      const endLat = 11.0200;
      const endLng = 76.9600;

      RouteSafetyMLEngine.processUserFeedback(
        rating: 5.0,
        tags: ['Well-lit street', 'Busy & crowded', 'Security / Police nearby'],
        comments: 'Excellent route, very safe with high security.',
        lat: endLat,
        lng: endLng,
      );

      final pred = RouteSafetyMLEngine.predictSafetyScore(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
      );

      expect(pred['score'], greaterThanOrEqualTo(80));
      expect(pred['level'], equals('Safe'));
      print('  ✓ Positive User Feedback Score Verified: ${pred['score']}% (${pred['level']})');
    });

    test('5. Safe Bypass Rerouting Engine generates alternative bypass waypoints', () {
      const startLat = 13.0827;
      const startLng = 80.2707;
      const endLat = 13.0890;
      const endLng = 80.2780;

      final bypassPoints = RouteSafetyMLEngine.generateBypassWaypoints(
        startLat,
        startLng,
        endLat,
        endLng,
      );

      expect(bypassPoints.length, greaterThanOrEqualTo(3));
      final midPoint = bypassPoints[1];
      expect(midPoint[0], isNot(equals((startLat + endLat) / 2)));
      expect(midPoint[1], isNot(equals((startLng + endLng) / 2)));
      print('  ✓ Safe Bypass Waypoints Generated cleanly around unsafe coordinates:');
      print('    - Start: ($startLat, $startLng)');
      print('    - Safe Detour Midpoint: (${midPoint[0]}, ${midPoint[1]})');
      print('    - Destination: ($endLat, $endLng)');
    });
  });
}
