// ignore_for_file: unused_import
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../domain/entities/risk_prediction.dart';
import '../../domain/repositories/risk_classifier_repository.dart';
import '../../../batches/domain/entities/batch.dart';
import 'rule_based_risk_classifier.dart';

/// Classificador TFLite on-device para Android/iOS.
/// Usa modelo em `assets/models/expiry_risk.tflite`.
/// Fallback automático para regras se o modelo não estiver disponível.
class TFLiteRiskClassifier implements RiskClassifierRepository {
  static const _modelAsset = 'assets/models/expiry_risk.tflite';
  static const _source = 'tflite';

  Interpreter? _interpreter;
  final _fallback = RuleBasedRiskClassifier();
  bool _modelLoaded = false;

  Future<void> init() async {
    try {
      final modelBytes = await rootBundle.load(_modelAsset);
      _interpreter = await Interpreter.fromBuffer(
        modelBytes.buffer.asUint8List(),
        options: InterpreterOptions()..threads = 2,
      );
      _modelLoaded = true;
    } catch (_) {
      _modelLoaded = false;
    }
  }

  @override
  Future<bool> get isAvailable async => _modelLoaded;

  @override
  Future<RiskPrediction> classify(Batch batch) async {
    if (!_modelLoaded || _interpreter == null) {
      return _fallback.classify(batch);
    }
    try {
      return _infer(batch);
    } catch (_) {
      return _fallback.classify(batch);
    }
  }

  @override
  Future<List<RiskPrediction>> classifyAll(List<Batch> batches) async {
    if (!_modelLoaded || _interpreter == null) {
      return _fallback.classifyAll(batches);
    }
    final results = <RiskPrediction>[];
    for (final batch in batches) {
      try {
        results.add(_infer(batch));
      } catch (_) {
        results.add(await _fallback.classify(batch));
      }
    }
    return results;
  }

  RiskPrediction _infer(Batch batch) {
    final features = BatchFeatures.fromBatch(batch);
    final input = [features.toList()];
    final output = [List.filled(3, 0.0)];
    _interpreter!.run(input, output);
    final probs = output[0];
    final level = _argmax(probs);
    return RiskPrediction(
      batchId: batch.id,
      productName: batch.productName,
      level: RiskLevel.values[level],
      probabilities: List<double>.from(probs),
      source: _source,
    );
  }

  static int _argmax(List<double> values) {
    int best = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return best;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
  }
}
