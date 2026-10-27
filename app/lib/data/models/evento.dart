class Evento {
  final int? id;
  final String titulo;
  final String? descricao;
  final int dataHoraInicio;
  final int dataHoraFim;
  final int criadoEm;
  final int? idLocal;
  final int? criadoPor;

  Evento({
    this.id,
    required this.titulo,
    this.descricao,
    required this.dataHoraInicio,
    required this.dataHoraFim,
    required this.criadoEm,
    this.idLocal,
    this.criadoPor,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'data_hora_inicio': dataHoraInicio,
      'data_hora_fim': dataHoraFim,
      'criado_em': criadoEm,
      'id_local': idLocal,
      'criado_por': criadoPor,
    };
  }

  factory Evento.fromMap(Map<String, dynamic> map) {
    return Evento(
      id: map['id'] as int?,
      titulo: map['titulo'] as String,
      descricao: map['descricao'] as String?,
      dataHoraInicio: map['data_hora_inicio'] as int,
      dataHoraFim: map['data_hora_fim'] as int,
      criadoEm: map['criado_em'] as int? ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      idLocal: map['id_local'] as int?,
      criadoPor: map['criado_por'] as int?,
    );
  }
}