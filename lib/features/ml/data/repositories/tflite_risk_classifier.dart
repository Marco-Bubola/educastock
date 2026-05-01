// ignore_for_file: unused_import
import '../../domain/entities/risk_prediction.dart';
import '../../domain/repositories/risk_classifier_repository.dart';
import '../../../batches/domain/entities/batch.dart';
import 'rule_based_risk_classifier.dart';

/// Stub do classificador TFLite.
/// Para ativar a inferência on-device em Android/iOS:
/// 1. Adicione `tflite_flutter: ^0.11.0` no pubspec.yaml
/// 2. Substitua este arquivo pela implementação real em scripts/ml/tflite_risk_classifier_impl.dart
class TFLiteRiskClassifier implements RiskClassifierRepository {
  final _fallback = RuleBasedRiskClassifier();

  Future<void> init() async {}

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<RiskPrediction> classify(Batch batch) => _fallback.classify(batch);

  @override
  Future<List<RiskPrediction>> classifyAll(List<Batch> batches) =>
      _fallback.classifyAll(batches);

  void dispose() {}
}
