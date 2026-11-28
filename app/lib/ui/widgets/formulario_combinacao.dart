import 'package:flutter/material.dart';

import '../../core/events/events_repository.dart';
import '../../data/models/enquete.dart';
import 'placez_componentes.dart';

/// Formulário compartilhado para criar ou regerar as opções de data de um
/// evento em rascunho.
class FormularioCombinacao extends StatefulWidget {
  final Future<String?> Function(EnqueteEntrada) onCriar;
  final EnqueteDisponibilidade? inicial;
  final bool regenerar;

  const FormularioCombinacao({
    super.key,
    required this.onCriar,
    this.inicial,
    this.regenerar = false,
  });

  @override
  State<FormularioCombinacao> createState() => _FormularioCombinacaoState();
}

class _FormularioCombinacaoState extends State<FormularioCombinacao> {
  static const _nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  late DateTime _dataInicio;
  late DateTime _dataFim;
  late final Set<int> _diasSemana;
  late TimeOfDay _horaInicio;
  late TimeOfDay _horaFim;
  bool _enviando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final inicial = widget.inicial;
    _dataInicio = _parseData(inicial?.dataInicio) ?? DateTime.now();
    _dataFim =
        _parseData(inicial?.dataFim) ??
        _dataInicio.add(const Duration(days: 14));
    _diasSemana = inicial != null && inicial.diasSemana.isNotEmpty
        ? inicial.diasSemana.toSet()
        : {6, 7};
    _horaInicio =
        _parseHora(inicial?.horaInicio) ?? const TimeOfDay(hour: 19, minute: 0);
    _horaFim =
        _parseHora(inicial?.horaFim) ?? const TimeOfDay(hour: 22, minute: 0);
  }

  DateTime? _parseData(String? valor) {
    if (valor == null || valor.isEmpty) return null;
    final data = DateTime.tryParse(valor);
    if (data == null) return null;
    return DateTime(data.year, data.month, data.day);
  }

  TimeOfDay? _parseHora(String? valor) {
    if (valor == null) return null;
    final partes = valor.split(':');
    if (partes.length < 2) return null;
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null || minuto == null) return null;
    if (hora < 0 || hora > 23 || minuto < 0 || minuto > 59) return null;
    return TimeOfDay(hour: hora, minute: minuto);
  }

  Future<void> _escolherData(bool inicio) async {
    final atual = inicio ? _dataInicio : _dataFim;
    final data = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (data == null || !mounted) return;
    setState(() {
      final escolhida = DateTime(data.year, data.month, data.day);
      if (inicio) {
        _dataInicio = escolhida;
        if (_dataFim.isBefore(_dataInicio)) {
          _dataFim = _dataInicio.add(const Duration(days: 7));
        }
      } else {
        _dataFim = escolhida;
      }
    });
  }

  Future<void> _escolherHora(bool inicio) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: inicio ? _horaInicio : _horaFim,
    );
    if (hora == null || !mounted) return;
    setState(() {
      if (inicio) {
        _horaInicio = hora;
      } else {
        _horaFim = hora;
      }
    });
  }

  Future<void> _salvar() async {
    if (_diasSemana.isEmpty) {
      setState(() => _erro = 'Selecione ao menos um dia da semana.');
      return;
    }
    if (_dataFim.isBefore(_dataInicio)) {
      setState(() => _erro = 'A data final deve ser após a inicial.');
      return;
    }
    final totalDias = _dataFim.difference(_dataInicio).inDays + 1;
    if (totalDias > 60) {
      setState(() => _erro = 'Use um intervalo de até 60 dias.');
      return;
    }
    if (_minutos(_horaFim) <= _minutos(_horaInicio)) {
      setState(() => _erro = 'O horário final deve ser após o inicial.');
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
    });

    final erro = await widget.onCriar(
      EnqueteEntrada(
        dataInicio: _isoDia(_dataInicio),
        dataFim: _isoDia(_dataFim),
        diasSemana: _diasSemana.toList()..sort(),
        horaInicio: _hora(_horaInicio),
        horaFim: _hora(_horaFim),
        fusoOffsetMinutos: DateTime.now().timeZoneOffset.inMinutes,
      ),
    );

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _erro = erro;
    });
  }

  int _minutos(TimeOfDay hora) => hora.hour * 60 + hora.minute;

  String _hora(TimeOfDay hora) {
    final h = hora.hour.toString().padLeft(2, '0');
    final m = hora.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _isoDia(DateTime data) {
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');
    return '${data.year}-$mes-$dia';
  }

  String _dataCurta(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          widget.regenerar
              ? 'Ajuste o período, os dias e o horário. Ao salvar, as opções '
                    'e os votos atuais serão substituídos.'
              : 'Escolha o período, os dias da semana e o horário. O app gera '
                    'uma opção para cada data possível e os convidados marcam '
                    'disponibilidade.',
          style: theme.textTheme.bodyMedium,
        ),
        if (widget.regenerar) ...[
          const SizedBox(height: 12),
          const AvisoPlacez(
            'As opções e os votos atuais serão substituídos.',
            icone: Icons.refresh,
          ),
        ],
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.date_range),
          title: const Text('Data inicial'),
          subtitle: Text(_dataCurta(_dataInicio)),
          onTap: () => _escolherData(true),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.date_range),
          title: const Text('Data final'),
          subtitle: Text(_dataCurta(_dataFim)),
          onTap: () => _escolherData(false),
        ),
        const SizedBox(height: 8),
        Text(
          'Dias da semana',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var dia = 1; dia <= 7; dia++)
              FilterChip(
                label: Text(_nomesDias[dia - 1]),
                selected: _diasSemana.contains(dia),
                showCheckmark: false,
                onSelected: (selecionado) {
                  setState(() {
                    if (selecionado) {
                      _diasSemana.add(dia);
                    } else {
                      _diasSemana.remove(dia);
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: const Text('Horário inicial'),
          subtitle: Text(_hora(_horaInicio)),
          onTap: () => _escolherHora(true),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: const Text('Horário final'),
          subtitle: Text(_hora(_horaFim)),
          onTap: () => _escolherHora(false),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 10),
          Text(
            _erro!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _enviando ? null : _salvar,
          icon: _enviando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: const Text('Salvar combinação'),
        ),
      ],
    );
  }
}
