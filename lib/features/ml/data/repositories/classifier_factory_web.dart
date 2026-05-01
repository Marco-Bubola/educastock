// Implementação web — nunca importa tflite_flutter (incompatível com dart:html).
import '../../domain/repositories/risk_classifier_repository.dart';
import 'rule_based_risk_classifier.dart';

Future<RiskClassifierRepository> buildClassifier() async {
  return RuleBasedRiskClassifier();
}
