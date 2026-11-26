import 'package:flutter/material.dart';

import '../../core/events/events_controller.dart';
import '../../core/events/events_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/enquete.dart';
import '../../data/models/evento.dart';

/// Aba do detalhe do evento para combinar o melhor dia.
class CombinacaoTab extends StatefulWidget {
  final EventsController eventsController;
  final int eventoId;
  final Evento eventoInicial;

  const CombinacaoTab({
    super.key,
    required this.eventsController,
    required this.eventoId,
    required this.eventoInicial,
  });

  @override
  State<CombinacaoTab> createState() => _CombinacaoTabState();
}

class _CombinacaoTabState extends State<CombinacaoTab> {
  static const _nomesDias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  ConsultaEnquete? _consulta;
  bool _carregando = true;
  String? _erro;
  int? _votandoOpcaoId;
  bool _aplicando = false;

  EventsController get _controller => widget.eventsController;

  Evento get _evento =>
      _controller.eventoPorId(widget.eventoId) ?? widget.eventoInicial;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final consulta = await _controller.consultarEnquete(widget.eventoId);
      if (!mounted) return;
      setState(() => _consulta = consulta);
    } on ApiException catch (erro) {
      if (!mounted) return;
      if (erro.statusCode == 404) {
        setState(() => _consulta = null);
      } else {
        setState(() => _erro = erro.message);
      }
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível carregar a combinação: $erro');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<String?> _criar(EnqueteEntrada entrada) async {
    try {
      final consulta = await _controller.criarEnquete(widget.eventoId, entrada);
      if (!mounted) return null;
      setState(() => _consulta = consulta);
      _avisar('Combinação de dias criada.');
      return null;
    } on ApiException catch (erro) {
      return erro.message;
    } catch (erro) {
      return 'Não foi possível criar a combinação: $erro';
    }
  }

  Future<void> _votar(
    OpcaoDisponibilidade opcao,
    VotoDisponibilidade status,
  ) async {
    if (_votandoOpcaoId != null || _aplicando) return;

    setState(() => _votandoOpcaoId = opcao.id);
    try {
      final consulta = await _controller.votarEnquete(widget.eventoId, [
        VotoEnquete(opcaoId: opcao.id, status: status),
      ]);
      if (!mounted) return;
      setState(() => _consulta = consulta);
    } on ApiException catch (erro) {
      if (mounted) _avisar(erro.message);
    } catch (erro) {
      if (mounted) _avisar('Não foi possível registrar o voto: $erro');
    } finally {
      if (mounted) setState(() => _votandoOpcaoId = null);
    }
  }

  Future<void> _aplicarMelhorDia() async {
    final melhor = _consulta?.melhorDia;
    if (melhor == null || _aplicando) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar melhor dia?'),
        content: Text(
          'O evento "${_evento.titulo}" será confirmado para '
          '${_rotuloData(melhor)} das ${melhor.horaInicio} às ${melhor.horaFim}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar evento'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _aplicando = true);
    final erro = await _controller.aplicarMelhorDia(widget.eventoId);
    if (!mounted) return;

    if (erro != null) {
      _avisar(erro);
      setState(() => _aplicando = false);
      return;
    }

    try {
      final consulta = await _controller.consultarEnquete(widget.eventoId);
      if (mounted) setState(() => _consulta = consulta);
    } catch (_) {
      // O evento já foi confirmado; a consulta é apenas um refresh.
    }
    if (!mounted) return;
    setState(() => _aplicando = false);
    _avisar('Evento confirmado para ${_rotuloData(melhor)}.');
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final evento = _evento;

        if (_carregando && _consulta == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_erro != null && _consulta == null) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _carregar,
                child: const Text('Tentar novamente'),
              ),
            ],
          );
        }

        final consulta = _consulta;
        if (consulta == null) {
          if (evento.status != 'RASCUNHO') {
            return _aviso(
              'Este evento não tem combinação de dias; a data já está definida.',
            );
          }
          if (!evento.souCriador) {
            return _aviso(
              'O criador ainda está configurando a combinação de dias.',
            );
          }
          return _FormularioCombinacao(onCriar: _criar);
        }

        return _conteudo(evento, consulta);
      },
    );
  }

  Widget _aviso(String mensagem) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.event_note_outlined, size: 40),
        const SizedBox(height: 12),
        Text(mensagem, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _conteudo(Evento evento, ConsultaEnquete consulta) {
    final theme = Theme.of(context);
    final enquete = consulta.enquete;
    final melhor = consulta.melhorDia;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Período: ${_dataCurta(enquete.dataInicio)} a '
            '${_dataCurta(enquete.dataFim)} · '
            '${enquete.horaInicio}–${enquete.horaFim}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (melhor != null) _cardMelhorDia(melhor, theme),
          const SizedBox(height: 16),
          Text(
            'Opções de data',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final opcao in enquete.opcoes) ...[
            _cardOpcao(evento, opcao, melhor, theme),
            const SizedBox(height: 8),
          ],
          if (evento.status == 'RASCUNHO') ...[
            const SizedBox(height: 12),
            if (evento.souCriador)
              FilledButton.icon(
                onPressed:
                    _aplicando || melhor == null || melhor.disponiveis == 0
                    ? null
                    : _aplicarMelhorDia,
                icon: _aplicando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.event_available),
                label: const Text('Aplicar melhor dia e confirmar'),
              )
            else
              _avisoLinha(
                'Marque sua disponibilidade. O criador escolhe o melhor dia '
                'e confirma o evento.',
              ),
          ] else
            _avisoLinha(
              'Evento confirmado para ${_formatarDataHora(evento.inicioEm)}.',
            ),
        ],
      ),
    );
  }

  Widget _cardMelhorDia(OpcaoDisponibilidade melhor, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Melhor dia',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_rotuloData(melhor)} · ${melhor.horaInicio}–${melhor.horaFim}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  melhor.totalVotos == 0
                      ? 'Ainda sem votos'
                      : '${melhor.disponiveis} disponíveis · '
                            '${melhor.percentual}% dos votos',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardOpcao(
    Evento evento,
    OpcaoDisponibilidade opcao,
    OpcaoDisponibilidade? melhor,
    ThemeData theme,
  ) {
    final ehMelhor = melhor?.id == opcao.id;
    final podeVotar = evento.status == 'RASCUNHO';
    final votando = _votandoOpcaoId == opcao.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: ehMelhor
            ? Border.all(color: theme.colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _rotuloData(opcao),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${opcao.horaInicio}–${opcao.horaFim}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: opcao.percentual / 100,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            opcao.totalVotos == 0
                ? 'Nenhum voto ainda'
                : '${opcao.disponiveis} de ${opcao.totalVotos} '
                      'disponíveis (${opcao.percentual}%)',
            style: theme.textTheme.bodySmall,
          ),
          if (podeVotar) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Disponível'),
                  selected: opcao.meuVoto == VotoDisponibilidade.disponivel,
                  onSelected: votando
                      ? null
                      : (_) => _votar(opcao, VotoDisponibilidade.disponivel),
                ),
                ChoiceChip(
                  label: const Text('Indisponível'),
                  selected: opcao.meuVoto == VotoDisponibilidade.indisponivel,
                  onSelected: votando
                      ? null
                      : (_) => _votar(opcao, VotoDisponibilidade.indisponivel),
                ),
                if (votando)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ] else if (opcao.meuVoto != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Seu voto: ${opcao.meuVoto!.rotulo}',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _avisoLinha(String mensagem) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        mensagem,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  String _rotuloData(OpcaoDisponibilidade opcao) {
    final data = opcao.dataCalendario;
    final dia = _nomesDias[data.weekday - 1];
    final diaMes = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia, $diaMes/$mes';
  }

  String _dataCurta(String iso) {
    final partes = iso.split('-');
    if (partes.length != 3) return iso;
    return '${partes[2]}/${partes[1]}';
  }

  String _formatarDataHora(DateTime? data) {
    if (data == null) return 'data a definir';
    final local = data.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${local.year} às $hora:$minuto';
  }
}

class _FormularioCombinacao extends StatefulWidget {
  final Future<String?> Function(EnqueteEntrada) onCriar;

  const _FormularioCombinacao({required this.onCriar});

  @override
  State<_FormularioCombinacao> createState() => _FormularioCombinacaoState();
}

class _FormularioCombinacaoState extends State<_FormularioCombinacao> {
  static const _nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  DateTime _dataInicio = DateTime.now();
  DateTime _dataFim = DateTime.now().add(const Duration(days: 14));
  final Set<int> _diasSemana = {6, 7};
  TimeOfDay _horaInicio = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _horaFim = const TimeOfDay(hour: 22, minute: 0);
  bool _enviando = false;
  String? _erro;

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
          'Escolha o período, os dias da semana e o horário. O app gera uma '
          'opção para cada data possível e os convidados marcam '
          'disponibilidade.',
          style: theme.textTheme.bodyMedium,
        ),
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
          label: const Text('Gerar opções de data'),
        ),
      ],
    );
  }
}
