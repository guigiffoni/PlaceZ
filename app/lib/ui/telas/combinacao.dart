import 'package:flutter/material.dart';

import '../../core/events/events_controller.dart';
import '../../core/events/events_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/enquete.dart';
import '../../data/models/evento.dart';
import '../../tema.dart';
import '../widgets/formulario_combinacao.dart';
import '../widgets/placez_componentes.dart';

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

  Future<void> _abrirRegerar() async {
    final consulta = _consulta;
    if (consulta == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (modalContext) => SizedBox(
        height: MediaQuery.sizeOf(modalContext).height * 0.9,
        child: FormularioCombinacao(
          inicial: consulta.enquete,
          regenerar: true,
          onCriar: (entrada) async {
            try {
              final nova = await _controller.criarEnquete(
                widget.eventoId,
                entrada,
                regenerar: true,
              );
              if (!mounted) return null;
              setState(() => _consulta = nova);
              if (modalContext.mounted) Navigator.of(modalContext).pop();
              _avisar('Opções de data regeradas.');
              return null;
            } on ApiException catch (erro) {
              return erro.message;
            } catch (erro) {
              return 'Não foi possível regerar as opções: $erro';
            }
          },
        ),
      ),
    );
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
          return FormularioCombinacao(onCriar: _criar);
        }

        return _conteudo(evento, consulta);
      },
    );
  }

  Widget _aviso(String mensagem) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        EstadoVazio(
          icone: Icons.event_note_outlined,
          titulo: 'Combinação de dias',
          descricao: mensagem,
          cor: Theme.of(context).colorScheme.acentoRoxo.frente,
        ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Período: ${_dataCurta(enquete.dataInicio)} a '
                  '${_dataCurta(enquete.dataFim)} · '
                  '${enquete.horaInicio}–${enquete.horaFim}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (evento.status == 'RASCUNHO' && evento.souCriador)
                TextButton.icon(
                  onPressed: _abrirRegerar,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Regerar'),
                ),
            ],
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
        borderRadius: PlacezTokens.bordaMd,
        border: Border.all(
          color: ehMelhor
              ? theme.colorScheme.primary
              : theme.colorScheme.bordaSutil,
          width: ehMelhor ? 1.5 : 1,
        ),
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
    return AvisoPlacez(mensagem);
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
