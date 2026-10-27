import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../data/models/evento.dart';
import '../../data/models/local.dart';
import '../../data/dao/evento_dao.dart';
import '../../data/dao/local_dao.dart';
import '../widgets/seletor_mapa.dart';

class TelaCadastroEvento extends StatefulWidget {
  const TelaCadastroEvento({super.key});

  @override
  State<TelaCadastroEvento> createState() => _TelaCadastroEventoState();
}

class _TelaCadastroEventoState extends State<TelaCadastroEvento> {
  final _formKey = GlobalKey<FormState>();
  final _eventoDao = EventoDao();
  final _localDao = LocalDao();

  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();

  DateTime _dataInicio = DateTime.now();
  DateTime _dataFim = DateTime.now().add(const Duration(hours: 1));
  Local? _localSelecionado;

  bool _salvando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  // --- MÉTODOS DE SELEÇÃO DE LOCAL ---

  void _abrirOpcoesDeLocal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // NOVA OPÇÃO: Escolher local existente
              ListTile(
                leading: const Icon(Icons.location_city),
                title: const Text('Selecionar Local Cadastrado'),
                onTap: () {
                  Navigator.pop(context);
                  _selecionarLocalDoBanco();
                },
              ),
              // Opção existente: Nominatim
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Digitar Endereço (Nominatim)'),
                onTap: () {
                  Navigator.pop(context);
                  _buscarEnderecoNominatim();
                },
              ),
              // Opção existente: Mapa
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Selecionar no Mapa'),
                onTap: () async {
                  Navigator.pop(context);
                  final latLng = await Navigator.push<LatLng>(
                    context,
                    MaterialPageRoute(builder: (context) => SeletorMapa()),
                  );
                  if (latLng != null) {
                    _salvarLocalComMapa(latLng.latitude, latLng.longitude);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selecionarLocalDoBanco() async {
    final locais = await _localDao.getAll();

    if (!mounted) return;

    if (locais.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum local cadastrado. Use o mapa ou busca.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecionar Local'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: locais.length,
              itemBuilder: (context, index) {
                final local = locais[index];
                return ListTile(
                  title: Text(local.nome ?? 'Sem nome'),
                  subtitle: Text(
                    local.endereco ?? 'Sem endereço',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    setState(() => _localSelecionado = local);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _buscarEnderecoNominatim() async {
    final controller = TextEditingController();

    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar Endereço'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Ex: Restaurante, SP'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );

    if (query == null || query.isEmpty) return;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5',
    );
    final response = await http.get(
      url,
      headers: {'User-Agent': 'com.example.app'},
    );

    if (response.statusCode == 200) {
      final List resultados = jsonDecode(response.body);

      if (resultados.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum local encontrado.')),
          );
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Resultados'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: resultados.length,
                itemBuilder: (context, index) {
                  final item = resultados[index];
                  return ListTile(
                    title: Text(item['display_name']),
                    onTap: () {
                      Navigator.pop(context); // Fecha resultados
                      final lat = double.parse(item['lat']);
                      final lon = double.parse(item['lon']);
                      _salvarLocalComMapa(
                        lat,
                        lon,
                        nome: item['display_name'].split(',')[0],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _salvarLocalComMapa(
    double lat,
    double lon, {
    String? nome,
  }) async {
    final novoLocal = Local(
      nome: nome ?? 'Local Selecionado',
      latitude: lat,
      longitude: lon,
    );
    final id = await _localDao.insert(novoLocal);

    if (mounted) {
      setState(() {
        _localSelecionado = Local(
          id: id,
          nome: novoLocal.nome,
          latitude: lat,
          longitude: lon,
        );
      });
    }
  }

  // --- MÉTODOS DE DATA E HORA ---

  Future<void> _selecionarDataHora(bool isInicio) async {
    final dataAtual = isInicio ? _dataInicio : _dataFim;

    final data = await showDatePicker(
      context: context,
      initialDate: dataAtual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (data == null) return;

    if (!mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dataAtual),
    );
    if (hora == null) return;

    setState(() {
      final novaData = DateTime(
        data.year,
        data.month,
        data.day,
        hora.hour,
        hora.minute,
      );
      if (isInicio) {
        _dataInicio = novaData;
        if (_dataFim.isBefore(_dataInicio)) {
          _dataFim = _dataInicio.add(const Duration(hours: 1));
        }
      } else {
        _dataFim = novaData;
      }
    });
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year;
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return "$dia/$mes/$ano às $hora:$minuto";
  }

  // --- MÉTODO DE SALVAR EVENTO ---

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dataFim.isBefore(_dataInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data de fim deve ser após a data de início.'),
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final evento = Evento(
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        dataHoraInicio: _dataInicio.millisecondsSinceEpoch ~/ 1000,
        dataHoraFim: _dataFim.millisecondsSinceEpoch ~/ 1000,
        criadoEm: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        idLocal: _localSelecionado?.id,
      );

      await _eventoDao.insert(evento);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento cadastrado com sucesso!')),
        );

        setState(() {
          _tituloController.clear();
          _descricaoController.clear();
          _dataInicio = DateTime.now();
          _dataFim = DateTime.now().add(const Duration(hours: 1));
          _localSelecionado = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Evento')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'O título é obrigatório';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descricaoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on),
              title: const Text('Local (opcional)'),
              subtitle: Text(
                _localSelecionado?.nome ?? 'Nenhum local selecionado',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _abrirOpcoesDeLocal,
            ),
            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Início *'),
              subtitle: Text(_formatarData(_dataInicio)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _selecionarDataHora(true),
            ),
            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Fim *'),
              subtitle: Text(_formatarData(_dataFim)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _selecionarDataHora(false),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _salvando ? null : _salvar,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _salvando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar Evento'),
            ),
          ],
        ),
      ),
    );
  }
}
