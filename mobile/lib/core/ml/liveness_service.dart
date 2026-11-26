import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import '../error/error_messages.dart';

/// Hasil deteksi wajah ternormalisasi `[face_score, cx, cy, w, h]` dalam `[0, 1]`
/// pada potongan area oval panduan (`ML_SPEC.md` §3.3).
class FaceDetectionBox extends Equatable {
  final double faceScore;
  final double cx;
  final double cy;
  final double width;
  final double height;
  final double threshold;

  const FaceDetectionBox({
    required this.faceScore,
    required this.cx,
    required this.cy,
    required this.width,
    required this.height,
    required this.threshold,
  });

  factory FaceDetectionBox.fromRawOutput(
    List<double> raw, {
    required double threshold,
  }) {
    if (raw.length != 5) {
      throw ArgumentError(
        'Output detektor wajah harus memiliki 5 elemen [face_score, cx, cy, w, h], '
        'diterima ${raw.length}.',
      );
    }
    for (final v in raw) {
      if (!v.isFinite) {
        throw StateError('Output detektor wajah mengandung NaN/Infinity.');
      }
    }

    return FaceDetectionBox(
      faceScore: raw[0].clamp(0.0, 1.0),
      cx: raw[1].clamp(0.0, 1.0),
      cy: raw[2].clamp(0.0, 1.0),
      width: raw[3].clamp(0.0, 1.0),
      height: raw[4].clamp(0.0, 1.0),
      threshold: threshold,
    );
  }

  /// Apakah skor wajah memenuhi ambang `detector_threshold.json`.
  bool get hasFace => faceScore >= threshold;

  /// Apakah pusat & ukuran kotak wajah berada secara wajar di dalam potongan oval.
  bool get isWellPositionedInOval =>
      hasFace &&
      cx >= 0.12 &&
      cx <= 0.88 &&
      cy >= 0.12 &&
      cy <= 0.88 &&
      width >= 0.18 &&
      height >= 0.18;

  @override
  List<Object?> get props => [faceScore, cx, cy, width, height, threshold];
}

/// Jenis tantangan aksi acak Liveness Level 1 (`ML_SPEC.md` §3.4, D-27).
enum LivenessChallengeType {
  shiftHorizontal,
  nodVertical,
  changeDistance;

  String get instructionText {
    switch (this) {
      case LivenessChallengeType.shiftHorizontal:
        return 'Tantangan Liveness: Geser wajah sedikit ke kiri atau kanan di dalam oval';
      case LivenessChallengeType.nodVertical:
        return 'Tantangan Liveness: Anggukkan/gerakkan wajah sedikit naik atau turun di dalam oval';
      case LivenessChallengeType.changeDistance:
        return 'Tantangan Liveness: Dekatkan atau jauhkan sedikit wajah Anda di dalam oval';
    }
  }

  String get shortLabel {
    switch (this) {
      case LivenessChallengeType.shiftHorizontal:
        return 'Geser Kiri/Kanan';
      case LivenessChallengeType.nodVertical:
        return 'Gerak Naik/Turun';
      case LivenessChallengeType.changeDistance:
        return 'Ubah Jarak Wajah';
    }
  }
}

/// Sesi tantangan Liveness L1 yang mengikat frame acuan awal (`baselineBox`) dengan instruksi acak.
class LivenessChallengeSession extends Equatable {
  final LivenessChallengeType type;
  final FaceDetectionBox baselineBox;

  const LivenessChallengeSession({
    required this.type,
    required this.baselineBox,
  });

  String get instructionText => type.instructionText;

  @override
  List<Object?> get props => [type, baselineBox];
}

/// Hasil evaluasi Liveness L1 antar-frame.
class LivenessEvaluationResult extends Equatable {
  final bool passed;
  final LivenessChallengeType challengeType;
  final double deltaCx;
  final double deltaCy;
  final double deltaScale;
  final String reason;

  const LivenessEvaluationResult({
    required this.passed,
    required this.challengeType,
    required this.deltaCx,
    required this.deltaCy,
    required this.deltaScale,
    required this.reason,
  });

  @override
  List<Object?> get props => [
        passed,
        challengeType,
        deltaCx,
        deltaCy,
        deltaScale,
        reason,
      ];
}

/// Kontrak layanan Liveness Level 1 (challenge-response tanpa model pihak ketiga, `ML_SPEC.md` §3.4).
abstract class LivenessService {
  LivenessChallengeSession createChallengeSession(
    FaceDetectionBox baselineBox, {
    LivenessChallengeType? forcedType,
  });

  LivenessEvaluationResult evaluate({
    required LivenessChallengeSession session,
    required FaceDetectionBox challengeBox,
  });
}

/// Implementasi Liveness L1 berbasis perubahan posisi `[cx, cy]` dan skala `[w, h]`
/// dari kotak detektor wajah buatan sendiri antar-frame (`ML_SPEC.md` §3.4).
class ChallengeResponseLivenessService implements LivenessService {
  final math.Random _random;
  final double minTranslationDelta;
  final double minScaleDelta;
  final double maxPlausibleJump;

  ChallengeResponseLivenessService({
    math.Random? random,
    this.minTranslationDelta = 0.014,
    this.minScaleDelta = 0.020,
    this.maxPlausibleJump = 0.65,
  }) : _random = random ?? math.Random();

  @override
  LivenessChallengeSession createChallengeSession(
    FaceDetectionBox baselineBox, {
    LivenessChallengeType? forcedType,
  }) {
    if (!baselineBox.isWellPositionedInOval) {
      throw StateError(ErrorMessages.fromCode('FACE_NOT_IN_OVAL'));
    }

    final chosenType = forcedType ??
        LivenessChallengeType
            .values[_random.nextInt(LivenessChallengeType.values.length)];

    return LivenessChallengeSession(
      type: chosenType,
      baselineBox: baselineBox,
    );
  }

  @override
  LivenessEvaluationResult evaluate({
    required LivenessChallengeSession session,
    required FaceDetectionBox challengeBox,
  }) {
    final base = session.baselineBox;

    if (!base.isWellPositionedInOval || !challengeBox.isWellPositionedInOval) {
      return LivenessEvaluationResult(
        passed: false,
        challengeType: session.type,
        deltaCx: 0.0,
        deltaCy: 0.0,
        deltaScale: 0.0,
        reason: ErrorMessages.fromCode('FACE_NOT_IN_OVAL'),
      );
    }

    final dCx = (challengeBox.cx - base.cx).abs();
    final dCy = (challengeBox.cy - base.cy).abs();
    final dW = (challengeBox.width - base.width).abs();
    final dH = (challengeBox.height - base.height).abs();
    final dScale = math.max(dW, dH);
    final totalMotion = math.sqrt(dCx * dCx + dCy * dCy) + dScale;

    if (totalMotion > maxPlausibleJump) {
      return LivenessEvaluationResult(
        passed: false,
        challengeType: session.type,
        deltaCx: dCx,
        deltaCy: dCy,
        deltaScale: dScale,
        reason: ErrorMessages.fromCode('LIVENESS_FAILED'),
      );
    }

    bool actionMatched = false;
    switch (session.type) {
      case LivenessChallengeType.shiftHorizontal:
        actionMatched = dCx >= minTranslationDelta;
        break;
      case LivenessChallengeType.nodVertical:
        actionMatched = dCy >= minTranslationDelta;
        break;
      case LivenessChallengeType.changeDistance:
        actionMatched = dScale >= minScaleDelta;
        break;
    }

    return LivenessEvaluationResult(
      passed: actionMatched,
      challengeType: session.type,
      deltaCx: dCx,
      deltaCy: dCy,
      deltaScale: dScale,
      reason: actionMatched
          ? 'Tantangan liveness berhasil diverifikasi.'
          : ErrorMessages.fromCode('LIVENESS_FAILED'),
    );
  }
}
