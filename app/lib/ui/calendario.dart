
import 'package:flutter/material.dart';

import '../data/atualizacoes.dart';
import '../data/dao/dao_evento.dart';
import '../data/dao/dao_local.dart';
import '../data/models/evento.dart';
import 'evento.dart';

class TelaCalendario extends StatefulWidget {
  const TelaCalendario({super.key});

  @override
  State<TelaCalendario> createState() => _TelaCalendarioState();
}

class _TelaCalendarioState extends State<TelaCalendario> {
  DateTime mesAtual = DateTime.now();

  final List<DateTime> diasSelecionados = [];
  final List<String> pessoas = [];

  List<Evento> eventos = [];

  bool carregando = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    Atualizacoes.eventos.addListener(carregarEventos);
    carregarEventos();
  }

  @override
  void dispose() {
    Atualizacoes.eventos.removeListener(carregarEventos);
    super.dispose();
  }

  Future<void> carregarEventos() async {
    try {
      final lista = await DaoEvento().getAll();

      lista.sort(
        (a, b) => a.dataHoraInicio.compareTo(b.dataHoraInicio),
      );

      if (!mounted) return;

      setState(() {
        eventos = lista;
        carregando = false;
        erro = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
        erro = e.toString();
      });
    }
  }

  bool mesmoDia(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  bool diaEstaSelecionado(DateTime data) {
    return diasSelecionados.any(
      (dia) => mesmoDia(dia, data),
    );
  }

  void selecionarDia(DateTime data) {
    setState(() {
      if (diaEstaSelecionado(data)) {
        diasSelecionados.removeWhere(
          (dia) => mesmoDia(dia, data),
        );
      } else {
        diasSelecionados.add(data);
      }
    });
  }

  List<Evento> eventosDoDia(DateTime dia) {
    final inicioDia = DateTime(
      dia.year,
      dia.month,
      dia.day,
    );

    final fimDia = DateTime(
      dia.year,
      dia.month,
      dia.day + 1,
    );

    return eventos.where((evento) {
      final inicio = DateTime.fromMillisecondsSinceEpoch(
        evento.dataHoraInicio * 1000,
      );

      final fim = DateTime.fromMillisecondsSinceEpoch(
        evento.dataHoraFim * 1000,
      );

      return inicio.isBefore(fimDia) &&
          fim.isAfter(inicioDia);
    }).toList();
  }

  String nomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return meses[mes - 1];
  }

  String formatarData(int segundos) {
    final data = DateTime.fromMillisecondsSinceEpoch(
      segundos * 1000,
    );

    String dois(int numero) {
      return numero.toString().padLeft(2, '0');
    }

    return '${dois(data.day)}/${dois(data.month)}/${data.year} '
        '${dois(data.hour)}:${dois(data.minute)}';
  }

  Future<void> adicionarPessoa() async {
    final controller = TextEditingController();

    final nome = await showDialog<String>(
      context: context,
      builder: (contexto) {
        return AlertDialog(
          title: const Text('Adicionar pessoa'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(contexto);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  contexto,
                  controller.text.trim(),
                );
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (nome != null && nome.isNotEmpty) {
      setState(() {
        pessoas.add(nome);
      });
    }
  }

  Future<void> abrirDia(DateTime data) async {
    final lista = eventosDoDia(data);

    if (lista.isEmpty) {
      selecionarDia(data);
      return;
    }

    if (lista.length == 1) {
      await mostrarDetalhes(lista.first);
      return;
    }

    final escolhido = await showModalBottomSheet<Evento>(
      context: context,
      builder: (contexto) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Eventos deste dia'),
              ),
              ...lista.map(
                (evento) => ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(evento.titulo),
                  subtitle: Text(
                    formatarData(evento.dataHoraInicio),
                  ),
                  onTap: () {
                    Navigator.pop(contexto, evento);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (escolhido != null && mounted) {
      await mostrarDetalhes(escolhido);
    }
  }

  Future<void> mostrarDetalhes(Evento evento) async {
    String nomeLocal = 'Não informado';

    try {
      final locais = await DaoLocal().getAll();

      for (final local in locais) {
        if (local.id == evento.idLocal) {
          nomeLocal = local.nome ?? 'Não informado';
          break;
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar local: $e'),
        ),
      );
    }

    if (!mounted) return;

    final acao = await showDialog<String>(
      context: context,
      builder: (contexto) {
        return AlertDialog(
          title: Text(evento.titulo),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Local: $nomeLocal'),
                const SizedBox(height: 8),
                Text(
                  'Início: ${formatarData(evento.dataHoraInicio)}',
                ),
                Text(
                  'Fim: ${formatarData(evento.dataHoraFim)}',
                ),
                if (evento.descricao?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text('Descrição: ${evento.descricao}'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(contexto);
              },
              child: const Text('Fechar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(contexto, 'editar');
              },
              child: const Text('Editar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(contexto, 'excluir');
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (acao == 'editar') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (contexto) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Editar evento'),
              ),
              body: TelaEvento(
                eventoExistente: evento,
              ),
            );
          },
        ),
      );

      await carregarEventos();
    }

    if (acao == 'excluir' && evento.id != null) {
      await excluirEvento(evento);
    }
  }

  Future<void> excluirEvento(Evento evento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) {
        return AlertDialog(
          title: const Text('Excluir evento?'),
          content: Text(
            'Deseja realmente excluir "${evento.titulo}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(contexto, false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(contexto, true);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || evento.id == null) {
      return;
    }

    try {
      await DaoEvento().delete(evento.id!);

      Atualizacoes.eventoAlterado();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evento excluído com sucesso!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir evento: $e'),
        ),
      );
    }
  }

  Widget construirCalendario() {
    final ano = mesAtual.year;
    final mes = mesAtual.month;

    final quantidadeDias = DateTime(
      ano,
      mes + 1,
      0,
    ).day;

    final primeiroDiaSemana = DateTime(
      ano,
      mes,
      1,
    ).weekday % 7;

    final totalCelulas =
        primeiroDiaSemana + quantidadeDias;

    final quantidadeSemanas =
        (totalCelulas / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final larguraCelula =
            constraints.maxWidth / 7;

        final alturaCelula =
            constraints.maxHeight / quantidadeSemanas;

        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio:
                larguraCelula / alturaCelula,
          ),
          itemCount: quantidadeSemanas * 7,
          itemBuilder: (context, index) {
            final numeroDia =
                index - primeiroDiaSemana + 1;

            if (numeroDia < 1 ||
                numeroDia > quantidadeDias) {
              return construirCelulaVazia();
            }

            final data = DateTime(
              ano,
              mes,
              numeroDia,
            );

            return construirDia(data, numeroDia);
          },
        );
      },
    );
  }

  Widget construirDia(
    DateTime data,
    int numeroDia,
  ) {
    final selecionado = diaEstaSelecionado(data);
    final lista = eventosDoDia(data);
    final cores = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => abrirDia(data),
      onLongPress: () => selecionarDia(data),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selecionado
              ? cores.primaryContainer
              : cores.surface,
          border: Border.all(
            color: cores.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selecionado
                    ? cores.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$numeroDia',
                style: TextStyle(
                  fontSize: 12,
                  color: selecionado
                      ? cores.onPrimary
                      : cores.onSurface,
                  fontWeight: selecionado
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            if (lista.isNotEmpty)
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: cores.secondaryContainer,
                    borderRadius:
                        BorderRadius.circular(4),
                  ),
                  child: Text(
                    lista.length == 1
                        ? lista.first.titulo
                        : '${lista.length} eventos',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: cores.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget construirCelulaVazia() {
    final cores = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cores.surfaceContainerLow,
        border: Border.all(
          color: cores.outlineVariant,
          width: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: adicionarPessoa,
                icon: const Icon(
                  Icons.person_add_alt_1,
                ),
                label: const Text('Adicionar pessoa'),
              ),
              const SizedBox(width: 8),
              ...pessoas.map(
                (nome) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InputChip(
                    label: Text(nome),
                    onDeleted: () {
                      setState(() {
                        pessoas.remove(nome);
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  mesAtual = DateTime(
                    mesAtual.year,
                    mesAtual.month - 1,
                  );
                });
              },
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${nomeMes(mesAtual.month)} ${mesAtual.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  mesAtual = DateTime(
                    mesAtual.year,
                    mesAtual.month + 1,
                  );
                });
              },
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              onPressed: carregarEventos,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),

        const SizedBox(height: 5),

        Row(
          children: [
            for (final dia in [
              'DOM',
              'SEG',
              'TER',
              'QUA',
              'QUI',
              'SEX',
              'SÁB',
            ])
              Expanded(
                child: Center(
                  child: Text(
                    dia,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 5),

        if (carregando)
          const LinearProgressIndicator(),

        if (erro != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Erro ao carregar eventos: $erro',
            ),
          ),

        Expanded(
          child: construirCalendario(),
        ),

        if (diasSelecionados.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${diasSelecionados.length} dia(s) selecionado(s)',
            ),
          ),
      ],
    );
  }
}


