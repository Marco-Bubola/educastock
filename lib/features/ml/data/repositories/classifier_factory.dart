// Ponto de entrada do factory — usa conditional imports para garantir que
// tflite_flutter NUNCA seja compilado no target web.
export 'classifier_factory_stub.dart'
    if (dart.library.io) 'classifier_factory_native.dart'
    if (dart.library.html) 'classifier_factory_web.dart'
    show buildClassifier;
