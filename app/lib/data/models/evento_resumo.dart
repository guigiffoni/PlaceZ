class EventoResumo {
  final int id;
  final String titulo;
  final DateTime? inicioEm;
  final String status;
  final String? localNome;

  const EventoResumo({
    required this.id,
    required this.titulo,
    this.inicioEm,
    this.status = 'CONFIRMADO',
    this.localNome,
  });

  bool get cancelado => status == 'CANCELADO';
  bool get rascunho => status == 'RASCUNHO';

  factory EventoResumo.fromJson(Map<String, dynamic> json) {
    final id = _comoInt(json['id']);
    final titulo = (json['titulo'] ?? '').toString().trim();
    if (id == null || titulo.isEmpty) {
      throw const FormatException('Evento inválido.');
    }

    return EventoResumo(
      id: id,
      titulo: titulo,
      inicioEm: _comoData(json['inicioEm']),
      status: (json['status'] ?? 'CONFIRMADO').toString(),
      localNome: _texto(json['localNome']),
    );
  }
}

int? _comoInt(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse(valor.toString());
}

String? _texto(dynamic valor) {
  final texto = valor?.toString().trim();
  return texto == null || texto.isEmpty ? null : texto;
}

DateTime? _comoData(dynamic valor) {
  if (valor == null) return null;
  if (valor is DateTime) return valor.toUtc();
  return DateTime.tryParse(valor.toString())?.toUtc();
}
