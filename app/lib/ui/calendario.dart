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
      var restantes = 60;

      while (!dia.isAfter(ultimoDia) && restantes > 0) {
        agrupados.putIfAbsent(dia, () => []).add(evento);
        dia = dia.add(const Duration(days: 1));
        restantes--;
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
    // O TableCalendar entrega os dias em UTC; usar os componentes evita
    // deslocar o dia ao converter para o fuso local.
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
    if (id == null) return;
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

    return Column(
      children: [
        if (_controller.carregando) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _controller.carregar(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_controller.erro != null)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                    ),
                  ),
                if (_controller.mostrandoCache)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: AvisoPlacez(
                        'Sem conexão com a API. Mostrando eventos salvos no aparelho.',
                      ),
                    ),
                  ),
                if (!_controller.auth.autenticado)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: AvisoPlacez(
                        'Entre para ver os eventos dos seus amigos.',
                      ),
                    ),
                  ),
                if (_controller.auth.autenticado &&
                    _controller.rascunhos.isNotEmpty)
                  SliverToBoxAdapter(child: _rascunhos(theme)),
                if (_controller.auth.autenticado &&
                    _controller.ranking.isNotEmpty)
                  SliverToBoxAdapter(child: _filtroPessoas(theme)),
                SliverToBoxAdapter(
                  child: Padding(
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
                                // Só há o formato mês, então o gesto vertical do
                                // calendário não faz nada; liberá-lo permite
                                // rolar a página começando sobre o calendário.
                                availableGestures:
                                    AvailableGestures.horizontalSwipe,
                                availableCalendarFormats: const {
                                  CalendarFormat.month: 'Mês',
                                },
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                  headerPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  titleTextStyle: theme.textTheme.titleMedium!
                                      .copyWith(fontWeight: FontWeight.w800),
                                  leftChevronIcon: Icon(
                                    Icons.chevron_left,
                                    color: theme.colorScheme.primary,
                                  ),
                                  rightChevronIcon: Icon(
                                    Icons.chevron_right,
                                    color: theme.colorScheme.primary,
                                  ),
                                  titleTextFormatter: (date, locale) =>
                                      _capitalizar(
                                        DateFormat(
                                          'MMMM y',
                                          'pt_BR',
                                        ).format(date),
                                      ),
                                ),
                                daysOfWeekStyle: DaysOfWeekStyle(
                                  weekdayStyle: theme.textTheme.labelSmall!
                                      .copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                  weekendStyle: theme.textTheme.labelSmall!
                                      .copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                selectedDayPredicate: (day) =>
                                    isSameDay(_selectedDay, day),
                                eventLoader: (day) {
                                  final dia = DateTime(
                                    day.year,
                                    day.month,
                                    day.day,
                                  );
                                  return _eventosPorDia[dia] ?? [];
                                },
                                calendarStyle: CalendarStyle(
                                  outsideDaysVisible: false,
                                  cellMargin: const EdgeInsets.all(4),
                                  defaultTextStyle: theme.textTheme.bodyMedium!,
                                  weekendTextStyle: theme.textTheme.bodyMedium!,
                                  todayDecoration: BoxDecoration(
                                    color: theme.colorScheme.tertiaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  todayTextStyle: theme.textTheme.bodyMedium!
                                      .copyWith(
                                        color: theme
                                            .colorScheme
                                            .onTertiaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                  selectedDecoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  selectedTextStyle: theme.textTheme.bodyMedium!
                                      .copyWith(
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
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                    _atualizarEventosDoDia();
                                  });
                                },
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
                                rowHeight: 54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CabecalhoDia(
                    titulo: _formatarDiaLongo(_selectedDay),
                    quantidade: _eventosDoDia.length,
                    theme: theme,
                    extent:
                        20 +
                        MediaQuery.textScalerOf(context)
                            .scale(theme.textTheme.titleSmall?.fontSize ?? 14) +
                        8,
                  ),
                ),
                if (_eventosDoDia.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      ),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: _eventosDoDia.length,
                    itemBuilder: (context, index) {
                      return _eventoTile(_eventosDoDia[index], theme);
                    },
                  ),
                if (_eventosDoDia.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: SizedBox(height: PlacezTokens.espMd),
                  ),
              ],
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

/// Cabeçalho do dia selecionado que permanece visível no topo enquanto a
/// lista de eventos rola.
class _CabecalhoDia extends SliverPersistentHeaderDelegate {
  final String titulo;
  final int quantidade;
  final ThemeData theme;
  final double extent;

  const _CabecalhoDia({
    required this.titulo,
    required this.quantidade,
    required this.theme,
    required this.extent,
  });

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: overlapsContent
                  ? theme.colorScheme.bordaSutil
                  : Colors.transparent,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (quantidade > 0)
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
                    '$quantidade',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CabecalhoDia oldDelegate) {
    return oldDelegate.titulo != titulo ||
        oldDelegate.quantidade != quantidade ||
        oldDelegate.theme != theme ||
        oldDelegate.extent != extent;
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
