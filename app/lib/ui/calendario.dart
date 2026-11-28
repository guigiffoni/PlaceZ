import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/events/events_controller.dart';
import '../data/models/evento.dart';
import '../tema.dart';
import 'cores_categoria.dart';
import 'telas/cadastro.dart';
import 'telas/evento_detalhe.dart';
import 'telas/login.dart';
import 'widgets/imagem_evento.dart';
import 'widgets/placez_componentes.dart';

class TelaCalendario extends StatefulWidget {
  final EventsController eventsController;

  const TelaCalendario({super.key, required this.eventsController});

  @override
  State<TelaCalendario> createState() => TelaCalendarioState();
}

class TelaCalendarioState extends State<TelaCalendario> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  Map<DateTime, List<Evento>> _eventosPorDia = {};
  List<Evento> _eventosDoDia = [];

  bool _abrindoDetalhe = false;

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

      final dataInicio = inicio.toLocal();
      var dia = DateTime(dataInicio.year, dataInicio.month, dataInicio.day);

      final fim = evento.fimEm?.toLocal();

      final ultimoDia = fim == null
          ? dia
          : DateTime(fim.year, fim.month, fim.day);

      while (!dia.isAfter(ultimoDia)) {
        agrupados.putIfAbsent(dia, () => []).add(evento);
        dia = DateTime(dia.year, dia.month, dia.day + 1);
      }
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

  void selecionarDia(DateTime data) {
    final local = data.toLocal();
    final dia = DateTime(local.year, local.month, local.day);

    setState(() {
      _selectedDay = dia;
      _focusedDay = dia;
      _atualizarEventosDoDia();
    });
  }

  Future<void> _selecionarDiaCalendario(
    DateTime selectedDay,
    DateTime focusedDay,
  ) async {
    if (!mounted || _abrindoDetalhe) return;

    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _atualizarEventosDoDia();
    });

    if (_eventosDoDia.length == 1) {
      await _abrirDetalhe(_eventosDoDia.first);
    }
  }

  String _formatarHora(DateTime data) {
    final local = data.toLocal();
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');

    return '$hora:$minuto';
  }

  bool _eventoMultiDia(Evento evento) {
    final inicio = evento.inicioEm;
    final fim = evento.fimEm;

    if (inicio == null || fim == null) return false;

    final a = inicio.toLocal();
    final b = fim.toLocal();

    return DateTime(a.year, a.month, a.day) != DateTime(b.year, b.month, b.day);
  }

  String _formatarDataCurta(DateTime data) {
    final local = data.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');

    return '$dia/$mes';
  }

  String _subtituloEvento(Evento evento) {
    final partes = <String>[
      if (_eventoMultiDia(evento)) 'Até ${_formatarDataCurta(evento.fimEm!)}',
      if (evento.local?.nome != null)
        evento.local!.nome!
      else
        'Sem local definido',
    ];

    return partes.join(' · ');
  }

  String _formatarDiaLongo(DateTime data) {
    final agora = DateTime.now();

    final ehHoje =
        data.year == agora.year &&
        data.month == agora.month &&
        data.day == agora.day;

    final texto = _capitalizar(
      DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(data),
    );

    return ehHoje ? 'Hoje · $texto' : texto;
  }

  String _capitalizar(String texto) {
    if (texto.isEmpty) return texto;

    return texto[0].toUpperCase() + texto.substring(1);
  }

  Future<void> _abrirDetalhe(Evento evento, {int abaInicial = 0}) async {
    final id = evento.id;

    if (id == null || !mounted || _abrindoDetalhe) return;

    _abrindoDetalhe = true;

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TelaDetalheEvento(
            eventsController: _controller,
            eventoId: id,
            eventoInicial: evento,
            abaInicial: abaInicial,
          ),
        ),
      );
    } finally {
      _abrindoDetalhe = false;
    }
  }

  Future<void> _criarEventoNoDia(DateTime dia) async {
    if (!_controller.auth.autenticado) {
      final autenticou = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => TelaLogin(
            authController: _controller.auth,
            motivo: 'Entre para criar um evento.',
          ),
        ),
      );

      if (autenticou != true || !mounted) return;
    }

    final criado = await Navigator.of(context).push<Evento>(
      MaterialPageRoute(
        builder: (context) => TelaCadastroEvento(
          eventsController: _controller,
          dataInicioInicial: dia,
          fecharAoSalvar: true,
        ),
      ),
    );

    if (criado != null && mounted) {
      selecionarDia(criado.inicioEm ?? dia);
    }
  }

  DateTime _normalizarDia(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  Map<Evento, int> _calcularLinhasEventos() {
    final eventos = _eventosPorDia.values
        .expand((lista) => lista)
        .toSet()
        .where(_eventoMultiDia)
        .toList();

    eventos.sort((a, b) {
      final inicio = a.inicioEm!.compareTo(b.inicioEm!);
      if (inicio != 0) return inicio;
      return a.titulo.compareTo(b.titulo);
    });

    final linhas = <Evento, int>{};
    final ocupacao = <DateTime>[];

    for (final evento in eventos) {
      final inicio = _normalizarDia(evento.inicioEm!.toLocal());
      final fim = _normalizarDia(evento.fimEm!.toLocal());

      var linha = 0;

      while (linha < ocupacao.length && !ocupacao[linha].isBefore(inicio)) {
        linha++;
      }

      if (linha == ocupacao.length) {
        ocupacao.add(fim);
      } else {
        ocupacao[linha] = fim;
      }

      linhas[evento] = linha;
    }

    return linhas;
  }

  Widget _marcadoresCalendario(
    BuildContext context,
    DateTime dia,
    List<Evento> eventos,
    Map<Evento, int> linhas,
  ) {
    final theme = Theme.of(context);
    final data = _normalizarDia(dia);
    final eventosUnicos = eventos
        .where((evento) => !_eventoMultiDia(evento))
        .toList();

    final barras = eventos.where(_eventoMultiDia).toList();

    const maxLinhas = 3;

    final ocultos = barras.where((evento) {
      return (linhas[evento] ?? 0) >= maxLinhas;
    }).length;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var linha = 0; linha < maxLinhas; linha++)
            SizedBox(
              height: 6,
              child: Stack(
                children: [
                  for (final evento in barras)
                    if (linhas[evento] == linha)
                      Positioned.fill(
                        top: 1,
                        bottom: 1,
                        child: _barraEvento(evento, data, theme),
                      ),
                ],
              ),
            ),
          if (eventosUnicos.isNotEmpty || ocultos > 0)
            SizedBox(
              height: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final evento in eventosUnicos.take(3))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: paletaCategoria(
                          theme.colorScheme,
                          evento.local?.categoria,
                        ).frente,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (ocultos > 0 || eventosUnicos.length > 3)
                    Text(
                      '+${ocultos + (eventosUnicos.length > 3 ? eventosUnicos.length - 3 : 0)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _corEventoCalendario(Evento evento) {
    const cores = <Color>[
      Color(0xFF67508B),
      Color(0xFF1976D2),
      Color(0xFFE67E22),
      Color(0xFF00897B),
      Color(0xFFD81B60),
      Color(0xFF689F38),
      Color(0xFF795548),
      Color(0xFF3949AB),
    ];

    final linhas = _calcularLinhasEventos();
    final linha = linhas[evento];

    if (linha != null) {
      return cores[linha % cores.length];
    }

    final identificador = evento.id?.toString() ?? evento.titulo;

    var indice = 0;

    for (final caractere in identificador.codeUnits) {
      indice = (indice * 31 + caractere) % cores.length;
    }

    return cores[indice];
  }

  Widget _barraEvento(Evento evento, DateTime dia, ThemeData theme) {
    final inicio = _normalizarDia(evento.inicioEm!.toLocal());
    final fim = _normalizarDia(evento.fimEm!.toLocal());

    final primeiroDia = isSameDay(dia, inicio);
    final ultimoDia = isSameDay(dia, fim);

    final inicioSemana = dia.weekday == DateTime.sunday;
    final fimSemana = dia.weekday == DateTime.saturday;

    final inicioMes = dia.day == 1;
    final fimMes =
        DateTime(dia.year, dia.month, dia.day + 1).month != dia.month;

    final arredondarInicio = primeiroDia || inicioSemana || inicioMes;

    final arredondarFim = ultimoDia || fimSemana || fimMes;

    return Tooltip(
      message: evento.titulo,
      child: Container(
        margin: EdgeInsets.only(
          left: arredondarInicio ? 2 : 0,
          right: arredondarFim ? 2 : 0,
        ),
        decoration: BoxDecoration(
          color: _corEventoCalendario(evento),
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(arredondarInicio ? 4 : 0),
            right: Radius.circular(arredondarFim ? 4 : 0),
          ),
        ),
      ),
    );
  }

  Widget _rascunhos(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.tertiaryContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Combinações pendentes',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            for (final rascunho in _controller.rascunhos)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.event_note_outlined,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                title: Text(rascunho.titulo),
                subtitle: Text(
                  rascunho.souCriador
                      ? 'Defina os dias ou confirme o melhor dia'
                      : 'Marque sua disponibilidade',
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                onTap: () => _abrirDetalhe(rascunho, abaInicial: 1),
              ),
          ],
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
    final linhasEventos = _calcularLinhasEventos();

    return Column(
      children: [
        if (_controller.carregando) const LinearProgressIndicator(),

        if (_controller.erro != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: AvisoPlacez(
              _controller.erro!,
              erro: true,
              onFechar: _controller.limparErro,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _controller.carregando
                  ? null
                  : _controller.atualizarCalendario,
              child: const Text('Tentar novamente'),
            ),
          ),
        ],

        if (_controller.mostrandoCache)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: AvisoPlacez(
              'Sem conexão com a API. Mostrando eventos salvos no aparelho.',
            ),
          ),

        if (!_controller.auth.autenticado)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: AvisoPlacez('Entre para ver os eventos dos seus amigos.'),
          ),

        if (_controller.auth.autenticado && _controller.rascunhos.isNotEmpty)
          _rascunhos(theme),

        if (_controller.auth.autenticado && _controller.ranking.isNotEmpty)
          _filtroPessoas(theme),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: PlacezTokens.bordaLg,
              border: Border.all(color: theme.colorScheme.bordaSutil),
            ),
            child: ClipRRect(
              borderRadius: PlacezTokens.bordaLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: theme.colorScheme.gradienteMarca,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                    child: TableCalendar<Evento>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      locale: 'pt_BR',
                      calendarFormat: CalendarFormat.month,

                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Mês',
                      },

                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        headerPadding: const EdgeInsets.symmetric(vertical: 8),
                        titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: theme.colorScheme.primary,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.primary,
                        ),
                        titleTextFormatter: (date, locale) => _capitalizar(
                          DateFormat('MMMM y', 'pt_BR').format(date),
                        ),
                      ),

                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: theme.textTheme.labelSmall!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        weekendStyle: theme.textTheme.labelSmall!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),

                      eventLoader: (day) {
                        final dia = DateTime(day.year, day.month, day.day);

                        return _eventosPorDia[dia] ?? [];
                      },

                      calendarBuilders: CalendarBuilders<Evento>(
                        markerBuilder: (context, day, eventos) {
                          if (eventos.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return _marcadoresCalendario(
                            context,
                            day,
                            eventos,
                            linhasEventos,
                          );
                        },
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        cellMargin: const EdgeInsets.fromLTRB(4, 2, 4, 24),
                        defaultTextStyle: theme.textTheme.bodyMedium!,
                        weekendTextStyle: theme.textTheme.bodyMedium!,

                        todayDecoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          shape: BoxShape.circle,
                        ),

                        todayTextStyle: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),

                        selectedDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),

                        selectedTextStyle: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),

                        markerDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),

                        markersMaxCount: 3,
                        markerSize: 5,
                        markersAlignment: Alignment.bottomCenter,
                      ),

                      onDaySelected: _selecionarDiaCalendario,

                      onDayLongPressed: (day, focusedDay) {
                        setState(() {
                          _selectedDay = day;
                          _focusedDay = focusedDay;
                          _atualizarEventosDoDia();
                        });

                        _criarEventoNoDia(day);
                      },

                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },

                      rowHeight: 72,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatarDiaLongo(_selectedDay),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_eventosDoDia.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_eventosDoDia.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (_eventosDoDia.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selecione um evento para ver os detalhes.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _controller.carregar(),
            child: _eventosDoDia.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const SizedBox(height: PlacezTokens.espMd),
                      _BotaoCriarEvento(
                        onTap: () => _criarEventoNoDia(_selectedDay),
                      ),
                      const SizedBox(height: PlacezTokens.espMd),
                      Center(
                        child: Text(
                          'Nenhum evento neste dia',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _eventosDoDia.length,
                    itemBuilder: (context, index) {
                      return _eventoTile(_eventosDoDia[index], theme);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _eventoTile(Evento evento, ThemeData theme) {
    final inicio = evento.inicioEm;

    final hora = inicio == null ? '--:--' : _formatarHora(inicio);

    final temLocal = evento.local?.nome != null;

    final paleta = paletaCategoria(theme.colorScheme, evento.local?.categoria);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: InkWell(
        onTap: () => _abrirDetalhe(evento),
        child: Padding(
          padding: const EdgeInsets.all(PlacezTokens.espMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: paleta.fundo,
                  borderRadius: PlacezTokens.bordaMd,
                  border: Border.all(color: paleta.borda),
                ),
                child: Column(
                  children: [
                    Text(
                      hora,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: paleta.frente,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _eventoMultiDia(evento)
                          ? _formatarDataCurta(evento.fimEm!)
                          : 'início',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: paleta.frente.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: PlacezTokens.espMd),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evento.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Icon(
                          temLocal
                              ? Icons.location_on_outlined
                              : Icons.event_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _subtituloEvento(evento),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (evento.contagem.vou > 0) ...[
                      const SizedBox(height: PlacezTokens.espSm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${evento.contagem.vou} '
                          '${evento.contagem.vou == 1 ? 'vai' : 'vão'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (evento.temImagem && evento.id != null) ...[
                const SizedBox(width: PlacezTokens.espSm),
                ImagemEvento(
                  auth: _controller.auth,
                  eventoId: evento.id!,
                  versao:
                      evento.imagemAtualizadaEm?.millisecondsSinceEpoch ?? 0,
                  width: 54,
                  height: 54,
                  borderRadius: PlacezTokens.bordaMd,
                ),
              ],

              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotaoCriarEvento extends StatelessWidget {
  final VoidCallback onTap;

  const _BotaoCriarEvento({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PlacezTokens.espLg),
      child: CustomPaint(
        painter: _DashedRoundedBorderPainter(
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
          radius: PlacezTokens.raioLg,
          dash: 7,
          gap: 5,
          strokeWidth: 1.5,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: PlacezTokens.bordaLg,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 30,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Criar evento',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distancia = 0.0;

      while (distancia < metric.length) {
        final fim = (distancia + dash).clamp(0.0, metric.length);

        canvas.drawPath(metric.extractPath(distancia, fim), paint);

        distancia = fim + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
