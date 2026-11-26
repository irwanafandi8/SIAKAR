import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'preprocess.dart';

/// Kontrak layanan ekstraksi embedding wajah 128-dimensi L2-normalized.
abstract class EmbeddingService {
  bool get isInitialized;

  Future<void> initialize();

  /// Ekstrak vektor embedding `[128]` L2-normalized dari citra mentah.
  Future<List<double>> extractEmbedding(img.Image rawImage);

  /// Ekstrak vektor embedding `[128]` L2-normalized dari bytes PNG/JPEG.
  Future<List<double>> extractEmbeddingFromBytes(Uint8List imageBytes);

  /// Jalankan inferensi TFLite langsung pada tensor NHWC `[1, S, S, 3]` float32.
  Future<List<double>> runOnPreprocessedTensor(Float32List inputNHWC);

  void dispose();
}

/// Utilitas matematika vektor untuk uji paritas & verifikasi L2-normalisasi.
class VectorMath {
  const VectorMath._();

  static double l2Norm(List<double> vector) {
    double sumSq = 0.0;
    for (final v in vector) {
      sumSq += v * v;
    }
    return math.sqrt(sumSq);
  }

  static List<double> l2Normalize(List<double> vector) {
    final norm = l2Norm(vector);
    if (norm <= 1e-12) {
      throw StateError('Norma L2 vektor embedding bernilai nol.');
    }
    return vector.map((v) => v / norm).toList(growable: false);
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || a.length != b.length) {
      throw ArgumentError(
        'Panjang kedua vektor harus sama dan tidak kosong '
        '(${a.length} vs ${b.length}).',
      );
    }
    double dot = 0.0;
    double normASq = 0.0;
    double normBSq = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normASq += a[i] * a[i];
      normBSq += b[i] * b[i];
    }
    final denom = math.sqrt(normASq) * math.sqrt(normBSq);
    if (denom <= 1e-12) {
      throw StateError('Norma vektor bernilai nol saat menghitung cosine.');
    }
    return (dot / denom).clamp(-1.0, 1.0);
  }
}

/// Implementasi `EmbeddingService` berbasis `tflite_flutter` memakai
/// `assets/models/siakar_embedding.tflite` (ML_SPEC §5).
class TfliteEmbeddingService implements EmbeddingService {
  static const String defaultModelAssetPath =
      'assets/models/siakar_embedding.tflite';
  static const int defaultEmbeddingDim = 128;

  final PreprocessService preprocessService;
  final String modelAssetPath;
  final File? modelFile;
  final int embeddingDim;
  final int numThreads;

  Interpreter? _interpreter;

  TfliteEmbeddingService({
    required this.preprocessService,
    this.modelAssetPath = defaultModelAssetPath,
    this.modelFile,
    this.embeddingDim = defaultEmbeddingDim,
    this.numThreads = 2,
  });

  /// Konstruktor untuk memuat model langsung dari berkas lokal (berguna untuk uji).
  factory TfliteEmbeddingService.fromFile(
    File file, {
    required PreprocessService preprocessService,
    int embeddingDim = defaultEmbeddingDim,
    int numThreads = 2,
  }) {
    return TfliteEmbeddingService(
      preprocessService: preprocessService,
      modelFile: file,
      embeddingDim: embeddingDim,
      numThreads: numThreads,
    );
  }

  @override
  bool get isInitialized => _interpreter != null;

  @override
  Future<void> initialize() async {
    if (_interpreter != null) return;

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
    final expectedSize = preprocessService.spec.inputSize;

    final validInput = inputShape.length == 4 &&
        inputShape[0] == 1 &&
        inputShape[1] == expectedSize &&
        inputShape[2] == expectedSize &&
        inputShape[3] == 3;

    if (!validInput) {
      interpreter.close();
      _interpreter = null;
      throw StateError(
        'Kontrak input TFLite tidak cocok: diharapkan [1, $expectedSize, '
        '$expectedSize, 3], diterima $inputShape.',
      );
    }

    final validOutput = outputShape.length == 2 &&
        outputShape[0] == 1 &&
        outputShape[1] == embeddingDim;

    if (!validOutput) {
      interpreter.close();
      _interpreter = null;
      throw StateError(
        'Kontrak output TFLite tidak cocok: diharapkan [1, $embeddingDim], '
        'diterima $outputShape.',
      );
    }
  }

  @override
  Future<List<double>> extractEmbedding(img.Image rawImage) async {
    final inputTensor = preprocessService.preprocess(rawImage);
    return runOnPreprocessedTensor(inputTensor);
  }

  @override
  Future<List<double>> extractEmbeddingFromBytes(Uint8List imageBytes) async {
    final inputTensor = preprocessService.preprocessBytes(imageBytes);
    return runOnPreprocessedTensor(inputTensor);
  }

  @override
  Future<List<double>> runOnPreprocessedTensor(Float32List inputNHWC) async {
    if (!isInitialized) {
      await initialize();
    }

    final inputSize = preprocessService.spec.inputSize;
    final expectedLen = 1 * inputSize * inputSize * 3;
    if (inputNHWC.length != expectedLen) {
      throw ArgumentError(
        'Panjang tensor input tidak valid: diharapkan $expectedLen, '
        'diterima ${inputNHWC.length}.',
      );
    }

    final interpreter = _interpreter!;
    final input4D = _reshapeTo4D(inputNHWC, inputSize);
    final output2D = List<List<double>>.generate(
      1,
      (_) => List<double>.filled(embeddingDim, 0.0),
    );

    interpreter.run(input4D, output2D);

    final rawEmbedding = output2D[0];
    for (final v in rawEmbedding) {
      if (!v.isFinite) {
        throw StateError('Output embedding TFLite mengandung NaN/Infinity.');
      }
    }

    // Model sudah L2-normalized di lapisan akhir (ML_SPEC §5);
    // pastikan tetap ter-normalisasi bila ada deviasi presisi floating point.
    final norm = VectorMath.l2Norm(rawEmbedding);
    if ((norm - 1.0).abs() > 1e-4) {
      return VectorMath.l2Normalize(rawEmbedding);
    }

    return List<double>.unmodifiable(rawEmbedding);
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
