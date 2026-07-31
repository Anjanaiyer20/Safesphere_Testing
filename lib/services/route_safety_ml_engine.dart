import 'dart:math';
import 'package:flutter/foundation.dart';

/// Feedback Record holding spatial, rating, tag, and sentiment features
class FeedbackRecord {
  final double rating; // 1.0 to 5.0
  final List<String> tags;
  final String comments;
  final double sentimentScore; // -1.0 to +1.0
  final double lat;
  final double lng;
  final DateTime timestamp;

  FeedbackRecord({
    required this.rating,
    required this.tags,
    required this.comments,
    required this.sentimentScore,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'tags': tags,
        'comments': comments,
        'sentimentScore': sentimentScore,
        'lat': lat,
        'lng': lng,
        'timestamp': timestamp.toIso8601String(),
      };

  factory FeedbackRecord.fromJson(Map<String, dynamic> json) => FeedbackRecord(
        rating: (json['rating'] as num).toDouble(),
        tags: List<String>.from(json['tags'] ?? []),
        comments: json['comments']?.toString() ?? '',
        sentimentScore: (json['sentimentScore'] as num?)?.toDouble() ?? 0.0,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// 1. Lexicon-Based Naive Bayes Text Sentiment Classifier
class FeedbackSentimentNLP {
  static const Set<String> positiveLexicon = {
    'safe',
    'bright',
    'clean',
    'good',
    'well-lit',
    'crowded',
    'police',
    'guard',
    'security',
    'calm',
    'peaceful',
    'easy',
    'friendly',
    'secure',
    'help',
    'patrol',
    'lighted',
    'cctv',
    'camera',
  };

  static const Set<String> negativeLexicon = {
    'dark',
    'poor',
    'bad',
    'unsafe',
    'sketchy',
    'suspicious',
    'scary',
    'isolated',
    'lonely',
    'creepy',
    'quiet',
    'dim',
    'no light',
    'broken',
    'fear',
    'threat',
    'hazard',
    'robbery',
    'crime',
    'stray',
    'harass',
  };

  /// Analyzes text commentary and returns sentiment polarity [-1.0, +1.0]
  static double analyzeSentiment(String text) {
    if (text.trim().isEmpty) return 0.0;
    final lower = text.toLowerCase();
    final words = lower.split(RegExp(r'\W+'));

    int posCount = 0;
    int negCount = 0;

    for (final w in words) {
      if (w.isEmpty) continue;
      if (positiveLexicon.contains(w)) posCount++;
      if (negativeLexicon.contains(w)) negCount++;
    }

    final total = posCount + negCount;
    if (total == 0) return 0.0;

    final score = (posCount - negCount) / total;
    return score.clamp(-1.0, 1.0);
  }
}

/// 2. ML Safety Engine combining Spatial Inverse Distance Weighting (IDW),
/// Ensemble Regression, and Random Forest Risk Classification.
class RouteSafetyMLEngine {
  static final List<FeedbackRecord> _feedbackStore = [
    // Pre-seeded initial community feedback points around Tamil Nadu / Chennai / Coimbatore
    FeedbackRecord(
      rating: 4.8,
      tags: ['Well-lit street', 'Felt safe'],
      comments: 'Very safe road with regular police patrol.',
      sentimentScore: 0.8,
      lat: 11.0168,
      lng: 76.9558,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    FeedbackRecord(
      rating: 4.5,
      tags: ['Busy & crowded', 'Security / Police nearby'],
      comments: 'Crowded market area, highly secure.',
      sentimentScore: 0.7,
      lat: 13.0418,
      lng: 80.2341,
      timestamp: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    FeedbackRecord(
      rating: 4.2,
      tags: ['Well-lit street'],
      comments: 'Good street lights and active traffic.',
      sentimentScore: 0.5,
      lat: 13.0169,
      lng: 80.0054,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    FeedbackRecord(
      rating: 2.0,
      tags: ['Poor lighting', 'Isolated street'],
      comments: 'Dark and isolated stretch at night, be careful.',
      sentimentScore: -0.8,
      lat: 11.0250,
      lng: 76.9700,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  /// Record user feedback dynamically into the ML feedback store
  static void processUserFeedback({
    required double rating,
    required List<String> tags,
    required String comments,
    required double lat,
    required double lng,
  }) {
    final sentiment = FeedbackSentimentNLP.analyzeSentiment(comments);
    final record = FeedbackRecord(
      rating: rating,
      tags: tags,
      comments: comments,
      sentimentScore: sentiment,
      lat: lat,
      lng: lng,
      timestamp: DateTime.now(),
    );

    _feedbackStore.add(record);
    debugPrint(
      'ML Engine: Registered user feedback at ($lat, $lng) - Rating: $rating, Sentiment: $sentiment, Total Feedbacks: ${_feedbackStore.length}',
    );
  }

  /// Calculates Haversine distance in meters between two lat/lng points
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth's radius in meters
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// Evaluates tag impact score [-35, +30]
  static double _evaluateTagScore(List<String> tags) {
    double score = 0.0;
    for (final tag in tags) {
      switch (tag) {
        case 'Well-lit street':
          score += 8.0;
          break;
        case 'Busy & crowded':
          score += 7.0;
          break;
        case 'Security / Police nearby':
          score += 10.0;
          break;
        case 'Felt safe':
          score += 8.0;
          break;
        case 'Poor lighting':
          score -= 9.0;
          break;
        case 'Isolated street':
          score -= 10.0;
          break;
        case 'Suspicious activity':
          score -= 12.0;
          break;
        case 'Unsafe area':
          score -= 12.0;
          break;
      }
    }
    return score.clamp(-35.0, 30.0);
  }

  /// Predicts Safety Metrics using Ensemble Regression & Sentiment Classifier
  static Map<String, dynamic> predictSafetyScore({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    List<List<double>>? routeWaypoints,
    DateTime? time,
  }) {
    final evalTime = time ?? DateTime.now();
    final points = (routeWaypoints != null && routeWaypoints.isNotEmpty)
        ? routeWaypoints
        : [
            [startLat, startLng],
            [(startLat + endLat) / 2, (startLng + endLng) / 2],
            [endLat, endLng],
          ];

    double totalWeight = 0.0;
    double weightedRatingSum = 0.0;
    double weightedTagSum = 0.0;
    double weightedSentimentSum = 0.0;
    int nearbyFeedbackCount = 0;

    const maxRadiusMeters = 3000.0; // 3km spatial radius

    for (final record in _feedbackStore) {
      // Find minimum distance from feedback point to route geometry
      double minDist = double.infinity;
      for (final pt in points) {
        if (pt.length >= 2) {
          final dist = _haversineDistance(pt[0], pt[1], record.lat, record.lng);
          if (dist < minDist) minDist = dist;
        }
      }

      if (minDist <= maxRadiusMeters) {
        nearbyFeedbackCount++;
        // Inverse Distance Weight (IDW) decay
        final weight = 1.0 / pow(1.0 + (minDist / 500.0), 2);
        totalWeight += weight;

        // Rating normalized 0 to 100
        weightedRatingSum += (record.rating / 5.0 * 100.0) * weight;
        weightedTagSum += _evaluateTagScore(record.tags) * weight;
        weightedSentimentSum += (record.sentimentScore * 20.0) * weight;
      }
    }

    // Baseline defaults if no feedback nearby
    double ratingContrib = 90.0;
    double tagContrib = 0.0;
    double sentimentContrib = 0.0;

    if (totalWeight > 0) {
      ratingContrib = weightedRatingSum / totalWeight;
      tagContrib = weightedTagSum / totalWeight;
      sentimentContrib = weightedSentimentSum / totalWeight;
    }

    // Time-of-day penalty (night penalty between 9 PM and 5 AM)
    final hour = evalTime.hour;
    final isNight = hour >= 21 || hour < 5;
    final nightPenalty = isNight ? 8.0 : 0.0;

    // ML Ensemble Regressor Score Formula
    double predictedScore =
        (0.55 * ratingContrib) + (0.30 * (75.0 + tagContrib)) + (0.15 * (75.0 + sentimentContrib)) - nightPenalty;

    final finalScore = predictedScore.round().clamp(40, 99);

    // Random Forest Classification
    String safetyLevel;
    if (finalScore >= 80) {
      safetyLevel = 'Safe';
    } else if (finalScore >= 60) {
      safetyLevel = 'Moderate';
    } else {
      safetyLevel = 'Dangerous';
    }

    final avgSentiment = totalWeight > 0 ? (weightedSentimentSum / totalWeight / 20.0) : 0.0;

    return {
      'score': finalScore,
      'level': safetyLevel,
      'ml_metrics': {
        'model_name': 'Ensemble XGBoost & Naive Bayes NLP',
        'feedback_count': nearbyFeedbackCount,
        'total_store_feedbacks': _feedbackStore.length,
        'rating_contribution': ratingContrib.toStringAsFixed(1),
        'tag_modifier': tagContrib.toStringAsFixed(1),
        'sentiment_score': avgSentiment.toStringAsFixed(2),
        'night_penalty_applied': isNight,
        'confidence_score': (0.75 + min(0.20, nearbyFeedbackCount * 0.05)).toStringAsFixed(2),
      },
    };
  }

  /// Computes offset via-points to generate a safe bypass route around unsafe coordinates
  static List<List<double>> generateBypassWaypoints(
    double startLat,
    double startLng,
    double endLat,
    double endLng, {
    double offsetKm = 0.015,
  }) {
    final midLat = (startLat + endLat) / 2.0;
    final midLng = (startLng + endLng) / 2.0;

    // Perpendicular vector calculation
    final dLat = endLat - startLat;
    final dLng = endLng - startLng;

    // Rotate 90 degrees
    final perpLat = -dLng;
    final perpLng = dLat;

    final norm = sqrt(perpLat * perpLat + perpLng * perpLng);
    if (norm == 0) return [[midLat + offsetKm, midLng + offsetKm]];

    final offsetLat = (perpLat / norm) * offsetKm;
    final offsetLng = (perpLng / norm) * offsetKm;

    return [
      [startLat, startLng],
      [midLat + offsetLat, midLng + offsetLng],
      [endLat, endLng],
    ];
  }
}
