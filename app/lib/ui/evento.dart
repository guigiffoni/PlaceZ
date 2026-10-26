
import 'package:flutter/material.dart';

import '../data/atualizacoes.dart';
import '../data/dao/dao_evento.dart';
import '../data/dao/dao_local.dart';
import '../data/models/evento.dart';
import '../data/models/local.dart';

class TelaEvento extends StatefulWidget {
  final Evento? eventoExistente;

  const TelaEvento({
    super.key,
    this.eventoExistente,
  });

  @override
  State<TelaEvento> createState() => _TelaEventoState();
}

class _TelaEventoState extends State<TelaEvento> {
  final tituloController = TextEditingController();
  final descricaoController = TextEditingController();
  final localController = TextEditingController();

  DateTime? inicio;
  DateTime? fim;

  bool salvando = false;

  @override
  void initState() {
    super.initState();

    final evento = widget.eventoExistente;

    if (evento != null) {
      tituloController.text = evento.titulo;
      descricaoController.text = evento.descricao ?? '';

      inicio = DateTime.fromMillisecondsSinceEpoch(
        evento.dataHoraInicio * 1000,
      );

      fim = DateTime.fromMillisecondsSinceEpoch(
        evento.dataHoraFim * 1000,
      );

      carregarLocal(evento.idLocal);
    }
  }

  Future<void> carregarLocal(int? idLocal) async {
    if (idLocal == null) return;

    try {
      final locais = await DaoLocal().getAll();

      for (final local in locais) {
        if (local.id == idLocal && mounted) {
          localController.text = local.nome ?? '';
          break;
        }
      }
    } catch (e) {
      mostrarMensagem('Erro ao carregar local: $e');
    }
  }

  @override
  void dispose() {
    tituloController.dispose();
    descricaoController.dispose();
    localController.dispose();
    super.dispose();
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  Future<DateTime?> selecionarDataHora(
    DateTime? dataAtual,
  ) async {
    final data = await showDatePicker(
      context: context,
      initialDate: dataAtual ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (data == null || !mounted) return null;

    final hora = await showTimePicker(
      context: context,
      initialTime: dataAtual == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(dataAtual),
    );

    if (hora == null) return null;

    return DateTime(
      data.year,
      data.month,
      data.day,
      hora.hour,
      hora.minute,
    );
  }

  String formatarData(DateTime? data) {
    if (data == null) {
      return 'Selecionar data e hora';
    }

    String dois(int n) => n.toString().padLeft(2, '0');

    return '${dois(data.day)}/${dois(data.month)}/${data.year} '
        '${dois(data.hour)}:${dois(data.minute)}';
  }

  Future<void> salvarEvento() async {
    if (salvando) return;

    if (tituloController.text.trim().isEmpty ||
        localController.text.trim().isEmpty ||
        inicio == null) {
      mostrarMensagem(
        'Preencha o nome, o local e a data de inÃ­cio.',
      );
      return;
    }

    final dataFim = fim ??
        inicio!.add(const Duration(hours: 1));

    if (!dataFim.isAfter(inicio!)) {
      mostrarMensagem(
        'A data final deve ser posterior Ã  inicial.',
      );
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      final daoLocal = DaoLocal();
      final daoEvento = DaoEvento();

      final locais = await daoLocal.getAll();
      final nomeLocal = localController.text.trim();

      int? idLocal;

      for (final local in locais) {
        if ((local.nome ?? '').toLowerCase() ==
            nomeLocal.toLowerCase()) {
          idLocal = local.id;
          break;
        }
      }

      if (idLocal == null) {
        idLocal = await daoLocal.insert(
          Local(nome: nomeLocal),
        );
      }

      final eventoAntigo = widget.eventoExistente;

      final evento = Evento(
        id: eventoAntigo?.id,
        titulo: tituloController.text.trim(),
        descricao: descricaoController.text.trim().isEmpty
            ? null
            : descricaoController.text.trim(),
        dataHoraInicio:
            inicio!.millisecondsSinceEpoch ~/ 1000,
        dataHoraFim:
            dataFim.millisecondsSinceEpoch ~/ 1000,
        criadoEm: eventoAntigo?.criadoEm ??
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
        idLocal: idLocal,
        criadoPor: eventoAntigo?.criadoPor,
      );

      if (eventoAntigo == null) {
        await daoEvento.insert(evento);
      } else {
        await daoEvento.update(evento);
      }

      Atualizacoes.eventoAlterado();

      if (!mounted) return;

      if (eventoAntigo != null) {
        Navigator.pop(context, true);
      } else {
        tituloController.clear();
        descricaoController.clear();
        localController.clear();

        setState(() {
          inicio = null;
          fim = null;
        });

        mostrarMensagem(
          'Evento salvo com sucesso!',
        );
      }
    } catch (e) {
      mostrarMensagem(
        'Erro ao salvar evento: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.eventoExistente == null
                ? 'Adicionar evento'
                : 'Editar evento',
            style: Theme.of(context).textTheme.headlineSmall,
          ),

          const SizedBox(height: 20),

          TextField(
            controller: tituloController,
            decoration: const InputDecoration(
              labelText: 'Nome do evento',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: descricaoController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'DescriÃ§Ã£o',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: localController,
            decoration: const InputDecoration(
              labelText: 'Local do evento',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(
              'InÃ­cio: ${formatarData(inicio)}',
            ),
            onPressed: () async {
              final data = await selecionarDataHora(inicio);

              if (data != null && mounted) {
                setState(() {
                  inicio = data;
                });
              }
            },
          ),

          const SizedBox(height: 8),

          OutlinedButton.icon(
            icon: const Icon(Icons.event_available),
            label: Text(
              'Fim: ${formatarData(fim)}',
            ),
            onPressed: () async {
              final data = await selecionarDataHora(
                fim ?? inicio,
              );

              if (data != null && mounted) {
                setState(() {
                  fim = data;
                });
              }
            },
          ),

          const SizedBox(height: 20),

          FilledButton.icon(
            icon: const Icon(Icons.save),
            onPressed: salvando ? null : salvarEvento,
            label: Text(
              salvando
                  ? 'Salvando...'
                  : widget.eventoExistente == null
                      ? 'Criar evento'
                      : 'Salvar alteraÃ§Ãµes',
            ),
          ),
        ],
      ),
    );
  }
}


