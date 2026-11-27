import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/events/events_controller.dart';
import '../../core/events/events_repository.dart';
import '../../core/friends/friends_repository.dart';
import '../../core/locations/fotos_lugar.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/amizade.dart';
import '../../data/models/evento.dart';
import '../../data/models/local.dart';
import '../../tema.dart';
import '../widgets/imagem_evento.dart';
import '../widgets/seletor_mapa.dart';
import 'selecao_local.dart';
import 'sugestao_local.dart';

class TelaCadastroEvento extends StatefulWidget {
  final EventsController eventsController;
  final Evento? eventoParaEditar;
  final DateTime? dataInicioInicial;
  final bool fecharAoSalvar;
  final bool mostrarAppBar;
  final VoidCallback? onBuscarNoCatalogo;

  const TelaCadastroEvento({
    super.key,
    required this.eventsController,
    this.eventoParaEditar,
    this.dataInicioInicial,
    this.fecharAoSalvar = false,
    this.mostrarAppBar = true,
    this.onBuscarNoCatalogo,
  });

  @override
  State<TelaCadastroEvento> createState() => TelaCadastroEventoState();
}

class TelaCadastroEventoState extends State<TelaCadastroEvento> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();

  DateTime _dataInicio = DateTime.now();
  DateTime _dataFim = DateTime.now().add(const Duration(hours: 1));
  Local? _localSelecionado;
  bool _privado = true;
  bool _permitirMembrosConvidar = false;
  bool _usarCombinacao = false;

  List<Amigo> _amigos = const [];
  Set<int> _convidadosSelecionados = <int>{};
  bool _carregandoAmigos = false;
  String? _erroAmigos;
  bool _salvando = false;

  Uint8List? _imagemBytes;
  String? _imagemMime;
  bool _imagemAtual = false;
  bool _imagemRemover = false;
  bool _imagemDoLugar = false;
  bool _carregandoImagem = false;

  FriendsRepository? _friendsRepository;

  bool get _modoEdicao => widget.eventoParaEditar != null;

  bool get _emRascunho => _modoEdicao
      ? widget.eventoParaEditar!.status == 'RASCUNHO'
      : _usarCombinacao;

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
      _usarCombinacao = evento.status == 'RASCUNHO';
      _imagemAtual = evento.temImagem;
    } else if (widget.dataInicioInicial != null) {
      // O TableCalendar entrega a data do dia como meia-noite UTC; usar os
      // componentes evita deslocar o dia ao converter para o fuso local.
      final dia = widget.dataInicioInicial!;
      _dataInicio = DateTime(dia.year, dia.month, dia.day, 19, 0);
      _dataFim = _dataInicio.add(const Duration(hours: 1));
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

  void definirLocalSelecionado(Local local) => _definirLocal(local);

  void _definirLocal(Local? local) {
    if (!mounted) return;
    setState(() {
      _localSelecionado = local;
      if (_imagemDoLugar) {
        _imagemBytes = null;
        _imagemMime = null;
        _imagemDoLugar = false;
      }
    });
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
                leading: const Icon(Icons.auto_awesome),
                title: const Text('Sugerir local para o grupo'),
                subtitle: const Text(
                  'Perto de todos, de alguns ou de uma pessoa',
                ),
                onTap: () => Navigator.of(context).pop('sugerir'),
              ),
              ListTile(
                leading: const Icon(Icons.travel_explore),
                title: const Text('Buscar lugar no catálogo'),
                subtitle: const Text('Nome, endereço, categoria e cidade'),
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
      case 'sugerir':
        final sugestao = await Navigator.of(context).push<Local>(
          MaterialPageRoute(
            builder: (context) => TelaSugestaoLocal(
              authController: widget.eventsController.auth,
              amigos: _amigos,
              convidadosSelecionados: _convidadosSelecionados,
            ),
          ),
        );
        if (sugestao != null && mounted) _definirLocal(sugestao);
        break;
      case 'catalogo':
        if (widget.onBuscarNoCatalogo != null) {
          widget.onBuscarNoCatalogo!();
          break;
        }
        final localCatalogo = await Navigator.of(context).push<Local>(
          MaterialPageRoute(
            builder: (context) =>
                TelaSelecaoLocal(authController: widget.eventsController.auth),
          ),
        );
        if (localCatalogo != null && mounted) {
          _definirLocal(localCatalogo);
        }
        break;
      case 'mapa':
        final latLng = await Navigator.push<LatLng>(
          context,
          MaterialPageRoute(builder: (context) => const SeletorMapa()),
        );
        if (latLng != null && mounted) {
          _definirLocal(
            Local(
              nome: 'Local selecionado no mapa',
              latitude: latLng.latitude,
              longitude: latLng.longitude,
            ),
          );
        }
        break;
      case 'nominatim':
        await _buscarEnderecoNominatim();
        break;
      case 'remover':
        _definirLocal(null);
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
      _definirLocal(
        Local(
          nome: endereco.split(',').first.trim(),
          endereco: endereco,
          latitude: lat,
          longitude: lon,
        ),
      );
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

  Future<void> _escolherImagem(ImageSource origem) async {
    if (_carregandoImagem) return;
    setState(() => _carregandoImagem = true);
    try {
      final arquivo = await ImagePicker().pickImage(
        source: origem,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (arquivo == null || !mounted) return;

      final bytes = await arquivo.readAsBytes();
      if (bytes.length > 600 * 1024) {
        _avisar('A imagem deve ter no máximo 600 KB.');
        return;
      }

      final nome = arquivo.name.toLowerCase();
      final mime = nome.endsWith('.png')
          ? 'image/png'
          : nome.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';

      setState(() {
        _imagemBytes = bytes;
        _imagemMime = mime;
        _imagemDoLugar = false;
        _imagemRemover = false;
        _imagemAtual = false;
      });
    } catch (erro) {
      _avisar('Não foi possível selecionar a imagem: $erro');
    } finally {
      if (mounted) setState(() => _carregandoImagem = false);
    }
  }

  Future<void> _usarFotoDoLugar() async {
    final local = _localSelecionado;
    if (local == null || _carregandoImagem) return;
    if (local.categoria == null) {
      _avisar('Este local não tem foto de catálogo para sugerir.');
      return;
    }

    setState(() => _carregandoImagem = true);
    try {
      final asset = FotosLugar.principal(local.categoria, local.nome);
      final dados = await rootBundle.load(asset);
      final bytes = dados.buffer.asUint8List();
      if (bytes.length > 600 * 1024) {
        _avisar('A foto do local é grande demais para o evento.');
        return;
      }

      setState(() {
        _imagemBytes = bytes;
        _imagemMime = 'image/jpeg';
        _imagemDoLugar = true;
        _imagemRemover = false;
        _imagemAtual = false;
      });
    } catch (erro) {
      _avisar('Não foi possível usar a foto do local: $erro');
    } finally {
      if (mounted) setState(() => _carregandoImagem = false);
    }
  }

  void _removerImagem() {
    setState(() {
      _imagemBytes = null;
      _imagemMime = null;
      _imagemDoLugar = false;
      _imagemRemover = _modoEdicao;
      _imagemAtual = false;
    });
  }

  Future<String?> _enviarImagemDoEvento(int eventoId) {
    final bytes = _imagemBytes;
    final mime = _imagemMime;
    if (bytes != null && mime != null) {
      return widget.eventsController.atualizarImagemEvento(
        eventoId,
        bytes,
        mime,
      );
    }
    if (_imagemRemover && _modoEdicao) {
      return widget.eventsController.removerImagemEvento(eventoId);
    }
    return Future.value(null);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final emRascunho = _emRascunho;
    if (!emRascunho && _dataFim.isBefore(_dataInicio)) {
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
        inicioEm: emRascunho ? null : _dataInicio.toUtc(),
        fimEm: emRascunho ? null : _dataFim.toUtc(),
        local: _localSelecionado,
        privado: _privado,
        permitirMembrosConvidar: _permitirMembrosConvidar,
        rascunho: emRascunho,
      );

      String? erro;
      String? erroImagem;
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
          erroImagem = await _enviarImagemDoEvento(evento.id!);
        }
      } else {
        erro = await widget.eventsController.criar(
          entrada,
          convidadoIds: _convidadosSelecionados.toList(),
        );
        final criado = widget.eventsController.ultimoEventoCriado;
        if (erro == null && criado?.id != null) {
          erroImagem = await _enviarImagemDoEvento(criado!.id!);
        }
      }

      if (!mounted) return;

      if (erro != null) {
        _avisar(erro);
        return;
      }
      if (erroImagem != null) {
        _avisar('Evento salvo, mas a imagem não pôde ser enviada: $erroImagem');
      }

      if (_modoEdicao || widget.fecharAoSalvar) {
        Navigator.of(context).pop(true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emRascunho
                ? 'Rascunho criado. Abra "Combinações pendentes" no '
                      'calendário para definir os dias.'
                : 'Evento criado com sucesso!',
          ),
        ),
      );
      setState(() {
        _tituloController.clear();
        _descricaoController.clear();
        _dataInicio = DateTime.now();
        _dataFim = _dataInicio.add(const Duration(hours: 1));
        _localSelecionado = null;
        _privado = true;
        _permitirMembrosConvidar = false;
        _usarCombinacao = false;
        _convidadosSelecionados = <int>{};
        _imagemBytes = null;
        _imagemMime = null;
        _imagemAtual = false;
        _imagemRemover = false;
        _imagemDoLugar = false;
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
      appBar: widget.mostrarAppBar
          ? AppBar(title: Text(_modoEdicao ? 'Editar evento' : 'Novo Evento'))
          : null,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _rotuloSecao('Sobre o evento', Icons.celebration_outlined, theme),
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
            const SizedBox(height: PlacezTokens.espMd),
            TextFormField(
              controller: _descricaoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PlacezTokens.espXl),
            _rotuloSecao('Quando e onde', Icons.event_outlined, theme),
            Card(
              child: Column(
                children: [
                  if (!_modoEdicao) ...[
                    SwitchListTile(
                      value: _usarCombinacao,
                      onChanged: (valor) =>
                          setState(() => _usarCombinacao = valor),
                      secondary: const Icon(Icons.auto_awesome_outlined),
                      title: const Text('Usar combinação de dias'),
                      subtitle: const Text(
                        'Cria um rascunho e deixa os convidados votarem nos '
                        'dias possíveis antes de confirmar.',
                      ),
                    ),
                    const Divider(),
                  ],
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Local (opcional)'),
                    subtitle: Text(
                      _localSelecionado == null
                          ? 'Nenhum local selecionado'
                          : _localSelecionado!.rotulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _abrirOpcoesDeLocal,
                  ),
                  if (_emRascunho) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: const Text('Data por combinação'),
                      subtitle: Text(
                        _modoEdicao
                            ? 'Ajuste o período e os dias na aba Combinação.'
                            : 'Depois de salvar, defina o período e os dias na '
                                  'aba Combinação.',
                      ),
                    ),
                  ] else ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Início *'),
                      subtitle: Text(_formatarData(_dataInicio)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selecionarDataHora(true),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: const Text('Fim *'),
                      subtitle: Text(_formatarData(_dataFim)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selecionarDataHora(false),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: PlacezTokens.espXl),
            _secaoImagem(theme),
            const SizedBox(height: PlacezTokens.espXl),
            _rotuloSecao('Privacidade e convites', Icons.lock_outline, theme),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _privado,
                    onChanged: (valor) => setState(() => _privado = valor),
                    secondary: const Icon(Icons.visibility_off_outlined),
                    title: const Text('Evento privado'),
                    subtitle: const Text(
                      'Somente convidados podem ver o evento.',
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    value: _permitirMembrosConvidar,
                    onChanged: (valor) =>
                        setState(() => _permitirMembrosConvidar = valor),
                    secondary: const Icon(Icons.person_add_alt_1_outlined),
                    title: const Text('Membros também podem convidar'),
                    subtitle: const Text(
                      'Qualquer convidado pode trazer novos amigos para o '
                      'evento.',
                    ),
                  ),
                ],
              ),
            ),
            if (_modoEdicao) ...[
              const SizedBox(height: PlacezTokens.espMd),
              Text(
                'Os convidados são gerenciados no detalhe do evento.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: PlacezTokens.espXl),
              _secaoConvidados(theme),
            ],
            const SizedBox(height: PlacezTokens.espXl),
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

  Widget _rotuloSecao(String titulo, IconData icone, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PlacezTokens.espSm),
      child: Row(
        children: [
          Icon(icone, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: PlacezTokens.espSm),
          Text(
            titulo,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _secaoImagem(ThemeData theme) {
    final local = _localSelecionado;
    final sugestao = local == null || local.categoria == null
        ? null
        : FotosLugar.principal(local.categoria, local.nome);
    final evento = widget.eventoParaEditar;
    final temImagemAtual =
        _imagemAtual && _modoEdicao && evento?.id != null && !_imagemRemover;

    Widget preview() {
      if (_imagemBytes != null) {
        return Image.memory(_imagemBytes!, fit: BoxFit.cover);
      }
      if (temImagemAtual) {
        return ImagemEvento(
          auth: widget.eventsController.auth,
          eventoId: evento!.id!,
          versao: evento.imagemAtualizadaEm?.millisecondsSinceEpoch ?? 0,
          fit: BoxFit.cover,
        );
      }
      return Container(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              'Nenhuma imagem escolhida',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rotuloSecao('Imagem do evento', Icons.image_outlined, theme),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(PlacezTokens.espMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: PlacezTokens.bordaMd,
                  child: SizedBox(height: 150, child: preview()),
                ),
                if (sugestao != null &&
                    _imagemBytes == null &&
                    !temImagemAtual) ...[
                  const SizedBox(height: PlacezTokens.espMd),
                  Text(
                    'Sugestão do local',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: PlacezTokens.bordaMd,
                    child: Image.asset(
                      sugestao,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _carregandoImagem ? null : _usarFotoDoLugar,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Usar foto do local'),
                  ),
                ],
                const SizedBox(height: PlacezTokens.espSm),
                Wrap(
                  spacing: PlacezTokens.espSm,
                  runSpacing: PlacezTokens.espXs,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _carregandoImagem
                          ? null
                          : () => _escolherImagem(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Galeria'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _carregandoImagem
                          ? null
                          : () => _escolherImagem(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Câmera'),
                    ),
                    if (_imagemBytes != null || temImagemAtual)
                      TextButton.icon(
                        onPressed: _carregandoImagem ? null : _removerImagem,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remover'),
                      ),
                  ],
                ),
                if (_carregandoImagem) ...[
                  const SizedBox(height: PlacezTokens.espSm),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 6),
                Text(
                  'A imagem aparece no detalhe do evento e no calendário. '
                  'Máximo de 600 KB.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
