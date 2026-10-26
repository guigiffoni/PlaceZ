
import 'package:flutter/foundation.dart';

class Atualizacoes {
  static final ValueNotifier<int> eventos = ValueNotifier<int>(0);

  static void eventoAlterado() {
    eventos.value++;
  }
}
