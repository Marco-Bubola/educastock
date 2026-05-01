// Stub — usado pelo Dart analyzer como fallback.
// Em tempo de execução, um dos arquivos concretos (native/web) é usado.
import '../../domain/repositories/risk_classifier_repository.dart';

Future<RiskClassifierRepository> buildClassifier() async {
  throw UnsupportedError('Plataforma não suportada');
}
