import 'package:app/ui/widgets/seletor_mapa.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/models/evento.dart';
import '../data/dao/evento_dao.dart';
import '../data/dao/local_dao.dart';

class TelaCalendario extends StatefulWidget {
  const TelaCalendario({super.key});

  @override
  State<TelaCalendario> createState() => _TelaCalendarioState();
}

class _TelaCalendarioState extends State<TelaCalendario> {
  final EventoDao _eventoDao = EventoDao();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = true;

  // Mapa que agrupa os eventos por dia (chave normalizada para meia-noite)
  Map<DateTime, List<Evento>> _eventosPorDia = {};

  // Lista de eventos do dia selecionado
  List<Evento> _eventosDoDia = [];

  @override
  void initState() {
    super.initState();
    _carregarEventos();
  }

  Future<void> _carregarEventos() async {
    try {
      final eventos = await _eventoDao.getAll();
      final Map<DateTime, List<Evento>> agrupados = {};

      for (var evento in eventos) {
        // Converte o timestamp salvo (segundos) para DateTime e normaliza para o dia
        final dataEvento = DateTime.fromMillisecondsSinceEpoch(
          evento.dataHoraInicio * 1000,
        );
        final diaNormalizado = DateTime.utc(
          dataEvento.year,
          dataEvento.month,
          dataEvento.day,
        );

        if (agrupados[diaNormalizado] == null) {
          agrupados[diaNormalizado] = [];
        }
        agrupados[diaNormalizado]!.add(evento);
      }

      if (mounted) {
        setState(() {
          _eventosPorDia = agrupados;
          _atualizarEventosDoDia();
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar eventos: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _atualizarEventosDoDia() {
    final diaNormalizado = DateTime.utc(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    _eventosDoDia = _eventosPorDia[diaNormalizado] ?? [];
  }

  // Formata o timestamp para exibir na lista (Ex: 14:30)
  String _formatarHora(int unixTimestamp) {
    final data = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return "$hora:$minuto";
  }

  void _abrirMapaFocado(double lat, double lng) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeletorMapa(
          posicaoInicial: LatLng(lat, lng),
          apenasVisualizacao: true, // Apenas visualizar, sem botão de salvar
        ),
      ),
    );
  }

  void _mostrarDetalhesEvento(Evento evento) {
    // Formatação básica das datas para exibição
    final inicio = DateTime.fromMillisecondsSinceEpoch(
      evento.dataHoraInicio * 1000,
    );
    final fim = DateTime.fromMillisecondsSinceEpoch(evento.dataHoraFim * 1000);
    final dataInicioStr =
        "${inicio.day.toString().padLeft(2, '0')}/${inicio.month.toString().padLeft(2, '0')} às ${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}";
    final dataFimStr =
        "${fim.day.toString().padLeft(2, '0')}/${fim.month.toString().padLeft(2, '0')} às ${fim.hour.toString().padLeft(2, '0')}:${fim.minute.toString().padLeft(2, '0')}";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(evento.titulo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (evento.descricao != null && evento.descricao!.isNotEmpty) ...[
                Text(evento.descricao!),
                const SizedBox(height: 16),
              ],
              Text("Início: $dataInicioStr"),
              Text("Fim: $dataFimStr"),

              // Se tiver local, mostra o botão para abrir o mapa
              if (evento.idLocal != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Ver no Mapa'),
                  onPressed: () async {
                    // Busca o local no banco (precisamos do LocalDao aqui)
                    final local = await LocalDao().getById(evento.idLocal!);
                    if (local != null &&
                        local.latitude != null &&
                        local.longitude != null) {
                      Navigator.pop(context); // Fecha o modal
                      // Abre o mapa focado no local (veremos como fazer abaixo)
                      _abrirMapaFocado(local.latitude!, local.longitude!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Local sem coordenadas cadastradas.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 1. O Calendário
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

          // Configuração dos pontos (dots)
          eventLoader: (day) {
            final diaNormalizado = DateTime.utc(day.year, day.month, day.day);
            return _eventosPorDia[diaNormalizado] ?? [];
          },
          calendarStyle: const CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Colors.blue, // Cor do pontinho
              shape: BoxShape.rectangle,
            ),
            markersMaxCount: 3, // Se tiver mais de 3 eventos no dia, corta
          ),

          // Atualização ao mudar o dia ou o mês
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
          rowHeight: 80.0,
        ),

        const Divider(),

        // 2. Lista de Eventos do Dia Selecionado
        Expanded(
          child: _eventosDoDia.isEmpty
              ? const Center(child: Text('Nenhum evento para este dia.'))
              : ListView.builder(
                  itemCount: _eventosDoDia.length,
                  itemBuilder: (context, index) {
                    final evento = _eventosDoDia[index];

                    return ListTile(
                      leading: const Icon(Icons.event),
                      title: Text(evento.titulo),
                      subtitle: Text(_formatarHora(evento.dataHoraInicio)),
                      onTap: () => _mostrarDetalhesEvento(evento),
                      trailing:
                          evento.descricao != null &&
                              evento.descricao!.isNotEmpty
                          ? const Icon(Icons.info_outline, size: 16)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
