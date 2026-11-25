import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/events/events_controller.dart';
import '../data/models/evento.dart';
import 'telas/evento_detalhe.dart';

class TelaCalendario extends StatefulWidget {
  final EventsController eventsController;

  const TelaCalendario({super.key, required this.eventsController});

  @override
  State<TelaCalendario> createState() => _TelaCalendarioState();
}

class _TelaCalendarioState extends State<TelaCalendario> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  Map<DateTime, List<Evento>> _eventosPorDia = {};
  List<Evento> _eventosDoDia = [];

  EventsController get _controller => widget.eventsController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_recalcular);
    _recalcular(notificar: false);
  }

  @override
  void dispose() {
    _controller.removeListener(_recalcular);
    super.dispose();
  }

  void _recalcular({bool notificar = true}) {
    final agrupados = <DateTime, List<Evento>>{};

    for (final evento in _controller.eventos) {
      final inicio = evento.inicioEm;
      if (inicio == null || !evento.confirmado) continue;

      final dataEvento = inicio.toLocal();
      final dia = DateTime(dataEvento.year, dataEvento.month, dataEvento.day);
      agrupados.putIfAbsent(dia, () => []).add(evento);
    }

    for (final lista in agrupados.values) {
      lista.sort(
        (a, b) => (a.inicioEm ?? DateTime.now()).compareTo(
          b.inicioEm ?? DateTime.now(),
        ),
      );
    }

    void aplicar() {
      _eventosPorDia = agrupados;
      _atualizarEventosDoDia();
    }

    if (notificar) {
      setState(aplicar);
    } else {
      aplicar();
    }
  }

  void _atualizarEventosDoDia() {
    final dia = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    _eventosDoDia = _eventosPorDia[dia] ?? [];
  }

  String _formatarHora(DateTime data) {
    final local = data.toLocal();
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  Future<void> _abrirDetalhe(Evento evento) async {
    final id = evento.id;
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TelaDetalheEvento(
          eventsController: _controller,
          eventoId: id,
          eventoInicial: evento,
        ),
      ),
    );
  }

  Widget _filtroPessoas(ThemeData theme) {
    final selecionadas = _controller.pessoasSelecionadas;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Icon(
            Icons.people_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final pessoa in _controller.ranking) ...[
                    FilterChip(
                      label: Text('${pessoa.nome} · ${pessoa.contagem}'),
                      selected: selecionadas.contains(pessoa.usuarioId),
                      showCheckmark: false,
                      onSelected: (_) =>
                          _controller.alternarPessoa(pessoa.usuarioId),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (selecionadas.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.close, size: 16),
                      label: const Text('Limpar'),
                      onPressed: _controller.limparFiltroPessoas,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (_controller.carregando) const LinearProgressIndicator(),
        if (_controller.erro != null)
          _Aviso(
            mensagem: _controller.erro!,
            erro: true,
            onFechar: _controller.limparErro,
          ),
        if (_controller.mostrandoCache)
          const _Aviso(
            mensagem:
                'Sem conexão com a API. Mostrando eventos salvos no aparelho.',
          ),
        if (!_controller.auth.autenticado)
          const _Aviso(mensagem: 'Entre para ver os eventos dos seus amigos.'),
        if (_controller.auth.autenticado && _controller.ranking.isNotEmpty)
          _filtroPessoas(theme),
        TableCalendar<Evento>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: (day) {
            final dia = DateTime(day.year, day.month, day.day);
            return _eventosPorDia[dia] ?? [];
          },
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.rectangle,
            ),
            markersMaxCount: 3,
          ),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
              _atualizarEventosDoDia();
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          rowHeight: 80,
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _controller.carregar(),
            child: _eventosDoDia.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('Nenhum evento para este dia.')),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _eventosDoDia.length,
                    itemBuilder: (context, index) {
                      final evento = _eventosDoDia[index];
                      return ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(evento.titulo),
                        subtitle: Text(
                          [
                            evento.inicioEm == null
                                ? 'Data a definir'
                                : _formatarHora(evento.inicioEm!),
                            if (evento.local?.nome != null) evento.local!.nome!,
                          ].join(' · '),
                        ),
                        trailing: evento.contagem.vou > 0
                            ? Text(
                                '${evento.contagem.vou} vão',
                                style: theme.textTheme.labelSmall,
                              )
                            : (evento.descricao != null
                                  ? const Icon(Icons.info_outline, size: 16)
                                  : null),
                        onTap: () => _abrirDetalhe(evento),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  final String mensagem;
  final VoidCallback? onFechar;
  final bool erro;

  const _Aviso({required this.mensagem, this.onFechar, this.erro = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fundo = erro
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final frente = erro
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: EdgeInsets.fromLTRB(12, 10, onFechar == null ? 12 : 4, 10),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            erro ? Icons.error_outline : Icons.info_outline,
            color: frente,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: theme.textTheme.bodySmall?.copyWith(color: frente),
            ),
          ),
          if (onFechar != null)
            IconButton(
              onPressed: onFechar,
              icon: Icon(Icons.close, size: 18, color: frente),
              tooltip: 'Fechar aviso',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
