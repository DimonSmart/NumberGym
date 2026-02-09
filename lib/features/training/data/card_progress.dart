import 'package:hive/hive.dart';

class CardCluster {
  final int lastAnswerAt;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;

  const CardCluster({
    required this.lastAnswerAt,
    required this.correctCount,
    required this.wrongCount,
    required this.skippedCount,
  });

  int get totalAttempts => correctCount + wrongCount + skippedCount;

  double get accuracy {
    final total = totalAttempts;
    if (total == 0) return 0;
    return correctCount / total;
  }

  CardCluster copyWith({
    int? lastAnswerAt,
    int? correctCount,
    int? wrongCount,
    int? skippedCount,
  }) {
    return CardCluster(
      lastAnswerAt: lastAnswerAt ?? this.lastAnswerAt,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      skippedCount: skippedCount ?? this.skippedCount,
    );
  }
}

class CardProgress {
  final bool learned;
  final List<CardCluster> clusters;
  final int learnedAt;
  final int firstAttemptAt;

  const CardProgress({
    required this.learned,
    required this.clusters,
    required this.learnedAt,
    required this.firstAttemptAt,
  });

  int get totalAttempts =>
      clusters.fold(0, (sum, cluster) => sum + cluster.totalAttempts);

  int get totalCorrect =>
      clusters.fold(0, (sum, cluster) => sum + cluster.correctCount);

  int get totalSkipped =>
      clusters.fold(0, (sum, cluster) => sum + cluster.skippedCount);

  int get totalWrong =>
      clusters.fold(0, (sum, cluster) => sum + cluster.wrongCount);

  CardCluster? get lastCluster => clusters.isEmpty ? null : clusters.last;

  double recentAccuracy({required int windowAttempts}) {
    if (windowAttempts <= 0) return 0;
    if (clusters.isEmpty) return 0;

    var remaining = windowAttempts;
    var attempts = 0;
    var weightedCorrect = 0.0;

    for (var i = clusters.length - 1; i >= 0 && remaining > 0; i -= 1) {
      final cluster = clusters[i];
      final clusterAttempts = cluster.totalAttempts;
      if (clusterAttempts == 0) {
        continue;
      }
      final taken = remaining < clusterAttempts ? remaining : clusterAttempts;
      attempts += taken;
      weightedCorrect += cluster.accuracy * taken;
      remaining -= taken;
    }

    if (attempts == 0) return 0;
    return weightedCorrect / attempts;
  }

  CardProgress copyWith({
    bool? learned,
    List<CardCluster>? clusters,
    int? learnedAt,
    int? firstAttemptAt,
  }) {
    return CardProgress(
      learned: learned ?? this.learned,
      clusters: clusters ?? this.clusters,
      learnedAt: learnedAt ?? this.learnedAt,
      firstAttemptAt: firstAttemptAt ?? this.firstAttemptAt,
    );
  }

  static const CardProgress empty = CardProgress(
    learned: false,
    clusters: <CardCluster>[],
    learnedAt: 0,
    firstAttemptAt: 0,
  );
}

class CardProgressAdapter extends TypeAdapter<CardProgress> {
  @override
  final int typeId = 0;

  @override
  CardProgress read(BinaryReader reader) {
    final learned = reader.readBool();
    final learnedAt = reader.readInt();
    final firstAttemptAt = reader.readInt();
    final clusterCount = reader.readInt();
    final clusters = <CardCluster>[];
    for (var i = 0; i < clusterCount; i += 1) {
      final lastAnswerAt = reader.readInt();
      final correctCount = reader.readInt();
      final wrongCount = reader.readInt();
      final skippedCount = reader.readInt();
      clusters.add(
        CardCluster(
          lastAnswerAt: lastAnswerAt,
          correctCount: correctCount,
          wrongCount: wrongCount,
          skippedCount: skippedCount,
        ),
      );
    }
    return CardProgress(
      learned: learned,
      clusters: clusters,
      learnedAt: learnedAt,
      firstAttemptAt: firstAttemptAt,
    );
  }

  @override
  void write(BinaryWriter writer, CardProgress obj) {
    writer.writeBool(obj.learned);
    writer.writeInt(obj.learnedAt);
    writer.writeInt(obj.firstAttemptAt);
    writer.writeInt(obj.clusters.length);
    for (final cluster in obj.clusters) {
      writer.writeInt(cluster.lastAnswerAt);
      writer.writeInt(cluster.correctCount);
      writer.writeInt(cluster.wrongCount);
      writer.writeInt(cluster.skippedCount);
    }
  }
}
