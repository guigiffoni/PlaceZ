import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/events/events_controller.dart';
import '../../core/events/events_repository.dart';
import '../../core/friends/friends_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/amizade.dart';
import '../../data/models/evento.dart';
import '../../data/models/local.dart';
import '../widgets/seletor_local_mock.dart';
import '../widgets/seletor_mapa.dart';

class TelaCadastroEvento extends StatefulWidget {
  final EventsController eventsController;
  final Evento? eventoParaEditar;

  const TelaCadastroEvento({
    super.key,
    required this.eventsController,
    this.eventoParaEditar,
  });

  @override
  State<TelaCadastroEvento> createState() => _TelaCadastroEventoState();
}

class _TelaCadastroEventoState extends State<TelaCadastroEvento> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();

  DateTime _dataInicio = DateTime.now();
  DateTime _dataFim = DateTime.now().add(const Duration(hours: 1));
  Local? _localSelecionado;
  bool _privado = true;
  bool _permitirMembrosConvidar = false;

  List<Amigo> _amigos = const [];
  Set<int> _convidadosSelecionados = <int>{};
  bool _carregandoAmigos = false;
  String? _erroAmigos;
  bool _salvando = false;

  FriendsRepository? _friendsRepository;

  bool get _modoEdicao => widget.eventoParaEditar != null;

  @override
  void initState() {
    super.initState();

    final evento = widget.eventoParaEditar;
    if (evento != null) {
      _tituloController.text = evento.titulo;
      _descricaoController.text = evento.descricao ?? '';
      _dataInicio = evento.inicioEm?.toLocal() ?? DateTime.now();
      _dataFim =
          evento.fimEm?.toLocal() ?? _dataInicio.add(const Duration(hours: 1));
      _localSelecionado = evento.local;
      _privado = evento.privado;
      _permitirMembrosConvidar = evento.permitirMembrosConvidar;
    }

    final auth = widget.eventsController.auth;
    if (auth.autenticado) {
      _friendsRepository = FriendsRepository(
        tokenProvider: () async => auth.sessao?.token,
        onUnauthorized: auth.tratarNaoAutorizado,
      );
      if (!_modoEdicao) _carregarAmigos();
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _carregarAmigos() async {
    final repositorio = _friendsRepository;
    if (repositorio == null) return;

    setState(() {
      _carregandoAmigos = true;
      _erroAmigos = null;
    });

    try {
      final amigos = await repositorio.listarAmigos();
      if (!mounted) return;
      setState(() {
        _amigos = amigos;
        _convidadosSelecionados = _convidadosSelecionados
            .where((id) => amigos.any((amigo) => amigo.usuario.id == id))
            .toSet();
      });
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() => _erroAmigos = erro.message);
    } catch (erro) {
      if (!mounted) return;
      setState(
        () => _erroAmigos = 'Não foi possível carregar seus amigos: $erro',
      );
    } finally {
      if (mounted) setState(() => _carregandoAmigos = false);
    }
  }

  Future<void> _abrirSelecaoConvidados() async {
    if (_amigos.isEmpty) return;

    final selecao = Set<int>.from(_convidadosSelecionados);
    final resultado = await showDialog<Set<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Convidar amigos'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: _amigos.length,
                  itemBuilder: (context, index) {
                    final amigo = _amigos[index];
                    return CheckboxListTile(
                      value: selecao.contains(amigo.usuario.id),
                      title: Text(amigo.usuario.nome),
                      subtitle: Text(amigo.usuario.identificador),
                      onChanged: (valor) {
                        setDialogState(() {
                          if (valor == true) {
                            selecao.add(amigo.usuario.id);
                          } else {
                            selecao.remove(amigo.usuario.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => setDialogState(selecao.clear),
                  child: const Text('Limpar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selecao),
                  child: const Text('Concluir'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado != null && mounted) {
      setState(() => _convidadosSelecionados = resultado);
    }
  }

  void _selecionarTodosOsAmigos() {
    if (_amigos.isEmpty) return;
    setState(() {
      _convidadosSelecionados = _amigos
          .map((amigo) => amigo.usuario.id)
          .toSet();
    });
  }

  Future<void> _abrirOpcoesDeLocal() async {
    final opcao = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.travel_explore),
                title: const Text('Buscar lugar no catálogo'),
                subtitle: const Text('Nome, endereço, categoria e distância'),
                onTap: () => Navigator.of(context).pop('catalogo'),
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Digitar endereço (Nominatim)'),
                onTap: () => Navigator.of(context).pop('nominatim'),
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Selecionar no mapa'),
                onTap: () => Navigator.of(context).pop('mapa'),
              ),
              if (_localSelecionado != null)
                ListTile(
                  leading: const Icon(Icons.location_off_outlined),
                  title: const Text('Remover local selecionado'),
                  onTap: () => Navigator.of(context).pop('remover'),
                ),
            ],
          ),
        );
      },
    );

    if (opcao == null || !mounted) return;

    switch (opcao) {
      case 'catalogo':
        final local = await SeletorLocalMock.abrir(context);
        if (local != null && mounted) {
          setState(() => _localSelecionado = local);
        }
        break;
      case 'mapa':
        final latLng = await Navigator.push<LatLng>(
          context,
          MaterialPageRoute(builder: (context) => const SeletorMapa()),
        );
        if (latLng != null && mounted) {
          setState(() {
            _localSelecionado = Local(
              nome: 'Local selecionado no mapa',
              latitude: latLng.latitude,
              longitude: latLng.longitude,
            );
          });
        }
        break;
      case 'nominatim':
        await _buscarEnderecoNominatim();
        break;
      case 'remover':
        setState(() => _localSelecionado = null);
        break;
    }
  }

  Future<void> _buscarEnderecoNominatim() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar endereço'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ex: Restaurante, Savassi',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );

    if (query == null || query.isEmpty) return;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.example.app'},
      );
      if (response.statusCode != 200) {
        _avisar('A busca de endereço falhou. Tente novamente.');
        return;
      }

      final resultados = jsonDecode(response.body);
      if (resultados is! List || resultados.isEmpty) {
        _avisar('Nenhum local encontrado.');
        return;
      }
      if (!mounted) return;

      final escolhido = await showDialog<Map<String, dynamic>>(
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
                  title: Text((item['display_name'] ?? '').toString()),
                  onTap: () =>
                      Navigator.of(context)
                          .pop(Map<String, dynamic>.from(item as Map)),
                );
              },
            ),
          ),
        ),
      );

      if (escolhido == null || !mounted) return;
      final lat = double.tryParse((escolhido['lat'] ?? '').toString());
      final lon = double.tryParse((escolhido['lon'] ?? '').toString());
      if (lat == null || lon == null) {
        _avisar('O endereço escolhido não tem coordenadas válidas.');
        return;
      }

      final endereco = (escolhido['display_name'] ?? '').toString();
      setState(() {
        _localSelecionado = Local(
          nome: endereco.split(',').first.trim(),
          endereco: endereco,
          latitude: lat,
          longitude: lon,
        );
      });
    } catch (erro) {
      _avisar('Não foi possível buscar o endereço: $erro');
    }
  }

  Future<void> _selecionarDataHora(bool isInicio) async {
    final dataAtual = isInicio ? _dataInicio : _dataFim;

    final data = await showDatePicker(
      context: context,
      initialDate: dataAtual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (data == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dataAtual),
    );
    if (hora == null || !mounted) return;

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
    return '$dia/$mes/$ano às $hora:$minuto';
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dataFim.isBefore(_dataInicio)) {
      _avisar('A data de fim deve ser após a data de início.');
      return;
    }

    setState(() => _salvando = true);

    try {
      final entrada = EventoEntrada(
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        inicioEm: _dataInicio.toUtc(),
        fimEm: _dataFim.toUtc(),
        local: _localSelecionado,
        privado: _privado,
        permitirMembrosConvidar: _permitirMembrosConvidar,
      );

      String? erro;
      if (_modoEdicao) {
        final evento = widget.eventoParaEditar!;
        erro = await widget.eventsController.editar(evento.id!, entrada);
        if (erro == null) {
          final atual =
              widget.eventsController.eventoPorId(evento.id!) ?? evento;
          if (atual.privado != _privado ||
              atual.permitirMembrosConvidar != _permitirMembrosConvidar) {
            final erroConfig = await widget.eventsController.atualizarConfig(
              evento.id!,
              privado: _privado,
              permitirMembrosConvidar: _permitirMembrosConvidar,
            );
            if (erroConfig != null) _avisar(erroConfig);
          }
        }
      } else {
        erro = await widget.eventsController.criar(
          entrada,
          convidadoIds: _convidadosSelecionados.toList(),
        );
      }

      if (!mounted) return;

      if (erro != null) {
        _avisar(erro);
        return;
      }

      if (_modoEdicao) {
        Navigator.of(context).pop(true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento criado com sucesso!')),
      );
      setState(() {
        _tituloController.clear();
        _descricaoController.clear();
        _dataInicio = DateTime.now();
        _dataFim = _dataInicio.add(const Duration(hours: 1));
        _localSelecionado = null;
        _privado = true;
        _permitirMembrosConvidar = false;
        _convidadosSelecionados = <int>{};
      });
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_modoEdicao ? 'Editar evento' : 'Novo Evento'),
      ),
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
                if (value.trim().length > 160) {
                  return 'Use no máximo 160 caracteres';
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
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on),
              title: const Text('Local (opcional)'),
              subtitle: Text(
                _localSelecionado == null
                    ? 'Nenhum local selecionado'
                    : _localSelecionado!.rotulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _privado,
              onChanged: (valor) => setState(() => _privado = valor),
              title: const Text('Evento privado'),
              subtitle: const Text('Somente convidados podem ver o evento.'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _permitirMembrosConvidar,
              onChanged: (valor) =>
                  setState(() => _permitirMembrosConvidar = valor),
              title: const Text('Membros também podem convidar'),
              subtitle: const Text(
                'Qualquer convidado pode trazer novos amigos para o evento.',
              ),
            ),
            if (_modoEdicao) ...[
              const SizedBox(height: 8),
              Text(
                'Os convidados são gerenciados no detalhe do evento.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              _secaoConvidados(theme),
            ],
            const SizedBox(height: 28),
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
                  : Text(_modoEdicao ? 'Salvar alterações' : 'Salvar Evento'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secaoConvidados(ThemeData theme) {
    final selecionados = _amigos
        .where((amigo) => _convidadosSelecionados.contains(amigo.usuario.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Convidados',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_carregandoAmigos)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_erroAmigos != null) ...[
          Text(
            _erroAmigos!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          TextButton(
            onPressed: _carregarAmigos,
            child: const Text('Tentar novamente'),
          ),
        ] else if (!_carregandoAmigos && _amigos.isEmpty) ...[
          Text(
            'Você ainda não tem amigos para convidar. Adicione amigos na aba '
            'Amigos e volte aqui.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_convidadosSelecionados.length} de ${_amigos.length} '
                  'amigos selecionados',
                ),
              ),
              TextButton(
                onPressed: _abrirSelecaoConvidados,
                child: const Text('Selecionar'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _selecionarTodosOsAmigos,
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('Convidar todos os amigos'),
            ),
          ),
          if (selecionados.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: selecionados
                  .map(
                    (amigo) => Chip(
                      label: Text(amigo.usuario.nome),
                      onDeleted: () => setState(
                        () => _convidadosSelecionados.remove(amigo.usuario.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ],
    );
  }
}
