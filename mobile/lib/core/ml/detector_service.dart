import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'liveness_service.dart';
import 'preprocess.dart';

/// Kontrak layanan detektor wajah buatan sendiri (`assets/models/detector.tflite`, ML_SPEC §3.3).
/// Input: `float32 [1, 64, 64, 3]` RGB `[-1, 1]` dari crop oval D-32.
/// Output: `float32 [1, 5]` yaitu `[face_score, cx, cy, w, h]` dalam `[0, 1]`.
abstract class DetectorService {
  static const int detectorInputSize = 64;
  static const int detectorOutputDim = 5;
  static const double defaultThreshold = 0.52;

  double get threshold;
  bool get isInitialized;

  Future<void> initialize();

  /// Praproses citra mentah ke tensor `[1, 64, 64, 3]` mengikuti kontrak D-32.
  Float32List preprocessForDetector(img.Image rawImage);

  /// Deteksi keberadaan & kotak wajah `[face_score, cx, cy, w, h]` pada area oval.
  Future<FaceDetectionBox> detect(img.Image rawImage);

  /// Deteksi keberadaan & kotak wajah dari bytes PNG/JPEG mentah.
  Future<FaceDetectionBox> detectFromBytes(Uint8List imageBytes);

  /// Jalankan inferensi TFLite langsung pada tensor `[1, 64, 64, 3]` float32.
  Future<FaceDetectionBox> runOnPreprocessedTensor(Float32List inputNHWC64);

  void dispose();
}

/// Implementasi `DetectorService` menggunakan `tflite_flutter` dan `detector_threshold.json`.
class TfliteDetectorService implements DetectorService {
  static const String defaultModelAssetPath = 'assets/models/detector.tflite';
  static const String defaultThresholdAssetPath =
      'assets/models/detector_threshold.json';

  final PreprocessService _detectorPreprocess;
  final String modelAssetPath;
  final String thresholdAssetPath;
  final File? modelFile;
  final File? thresholdFile;
  final int numThreads;

  double _threshold;
  Interpreter? _interpreter;

  TfliteDetectorService({
    required PreprocessService preprocessService,
    this.modelAssetPath = defaultModelAssetPath,
    this.thresholdAssetPath = defaultThresholdAssetPath,
    this.modelFile,
    this.thresholdFile,
    double? initialThreshold,
    this.numThreads = 2,
  })  : _detectorPreprocess = preprocessService.withInputSize(
          DetectorService.detectorInputSize,
        ),
        _threshold = initialThreshold ?? DetectorService.defaultThreshold;

  /// Konstruktor langsung dari berkas lokal (berguna pada pengujian unit/golden).
  factory TfliteDetectorService.fromFiles({
    required File modelFile,
    File? thresholdFile,
    required PreprocessService preprocessService,
    double? initialThreshold,
    int numThreads = 2,
  }) {
    double? parsedThreshold = initialThreshold;
    if (parsedThreshold == null &&
        thresholdFile != null &&
        thresholdFile.existsSync()) {
      final map =
          jsonDecode(thresholdFile.readAsStringSync()) as Map<String, dynamic>;
      parsedThreshold = (map['threshold'] as num?)?.toDouble();
    }

    return TfliteDetectorService(
      preprocessService: preprocessService,
      modelFile: modelFile,
      thresholdFile: thresholdFile,
      initialThreshold: parsedThreshold,
      numThreads: numThreads,
    );
  }

  /// Muat ambang detektor dari `assets/models/detector_threshold.json`.
  static Future<double> loadThresholdFromAsset([
    String assetPath = defaultThresholdAssetPath,
  ]) async {
    final jsonStr = await rootBundle.loadString(assetPath);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return (map['threshold'] as num?)?.toDouble() ??
        DetectorService.defaultThreshold;
  }

  @override
  double get threshold => _threshold;

  @override
  bool get isInitialized => _interpreter != null;

  @override
  Future<void> initialize() async {
    if (_interpreter != null) return;

    if (thresholdFile != null && thresholdFile!.existsSync()) {
      final map =
          jsonDecode(thresholdFile!.readAsStringSync()) as Map<String, dynamic>;
      _threshold =
          (map['threshold'] as num?)?.toDouble() ?? _threshold;
    } else if (modelFile == null) {
      try {
        _threshold = await loadThresholdFromAsset(thresholdAssetPath);
      } catch (_) {
        // Pertahankan _threshold fallback (0.52) bila aset belum terbundel pada tes terisolasi
      }
    }

    final options = InterpreterOptions()..threads = numThreads;
    if (modelFile != null) {
      _interpreter = Interpreter.fromFile(modelFile!, options: options);
    } else {
      _interpreter = await Interpreter.fromAsset(
        modelAssetPath,
        options: options,
      );
    }

    _validateTensorContract(_interpreter!);
  }

  void _validateTensorContract(Interpreter interpreter) {
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    const expectedSize = DetectorService.detectorInputSize;
    const expectedOut = DetectorService.detectorOutputDim;

    final validInput = inputShape.length == 4 &&
        inputShape[0] == 1 &&
        inputShape[1] == expectedSize &&
        inputShape[2] == expectedSize &&
        inputShape[3] == 3;

    if (!validInput) {
      interpreter.close();
      _interpreter = null;
      throw StateError(
        'Kontrak input detektor TFLite tidak cocok: diharapkan '
        '[1, $expectedSize, $expectedSize, 3], diterima $inputShape.',
      );
    }

    final validOutput = outputShape.length == 2 &&
        outputShape[0] == 1 &&
        outputShape[1] == expectedOut;

    if (!validOutput) {
      interpreter.close();
      _interpreter = null;
      throw StateError(
        'Kontrak output detektor TFLite tidak cocok: diharapkan '
        '[1, $expectedOut], diterima $outputShape.',
      );
    }
  }

  @override
  Float32List preprocessForDetector(img.Image rawImage) {
    return _detectorPreprocess.preprocess(rawImage);
  }

  @override
  Future<FaceDetectionBox> detect(img.Image rawImage) async {
    final tensor = preprocessForDetector(rawImage);
    return runOnPreprocessedTensor(tensor);
  }

  @override
  Future<FaceDetectionBox> detectFromBytes(Uint8List imageBytes) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Gagal mendekode bytes citra untuk detektor wajah.');
    }
    return detect(decoded);
  }

  @override
  Future<FaceDetectionBox> runOnPreprocessedTensor(
    Float32List inputNHWC64,
  ) async {
    if (!isInitialized) {
      await initialize();
    }

    const size = DetectorService.detectorInputSize;
    const expectedLen = 1 * size * size * 3;
    if (inputNHWC64.length != expectedLen) {
      throw ArgumentError(
        'Panjang tensor input detektor tidak valid: diharapkan $expectedLen, '
        'diterima ${inputNHWC64.length}.',
      );
    }

    final interpreter = _interpreter!;
    final input4D = _reshapeTo4D(inputNHWC64, size);
    final output2D = List<List<double>>.generate(
      1,
      (_) => List<double>.filled(DetectorService.detectorOutputDim, 0.0),
    );

    interpreter.run(input4D, output2D);

    return FaceDetectionBox.fromRawOutput(
      output2D[0],
      threshold: _threshold,
    );
  }

  static List<List<List<List<double>>>> _reshapeTo4D(
    Float32List flat,
    int size,
  ) {
    int idx = 0;
    return [
      List<List<List<double>>>.generate(
        size,
        (_) => List<List<double>>.generate(
          size,
          (_) => <double>[
            flat[idx++],
            flat[idx++],
            flat[idx++],
          ],
          growable: false,
        ),
        growable: false,
      ),
    ];
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
