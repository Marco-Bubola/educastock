// Implementação nativa (Android / iOS / desktop) — compila com dart:ffi.
import '../../domain/repositories/risk_classifier_repository.dart';
import 'tflite_risk_classifier.dart';
import 'rule_based_risk_classifier.dart';

Future<RiskClassifierRepository> buildClassifier() async {
  final clf = TFLiteRiskClassifier();
  await clf.init();
  if (await clf.isAvailable) return clf;
  return RuleBasedRiskClassifier();
}
