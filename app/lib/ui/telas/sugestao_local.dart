import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/events/local_catalog.dart';
import '../../core/locations/locations_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/amizade.dart';
import '../../data/models/localizacao.dart';
import '../../tema.dart';
import '../widgets/placez_componentes.dart';

enum _ModoSugestao { todos, alguns, um }

class TelaSugestaoLocal extends StatefulWidget {
  final AuthController authController;
  final List<Amigo> amigos;
  final Set<int> convidadosSelecionados;

  const TelaSugestaoLocal({
    super.key,
    required this.authController,
    required this.amigos,
    required this.convidadosSelecionados,
  });

  @override
  State<TelaSugestaoLocal> createState() => _TelaSugestaoLocalState();
}

class _TelaSugestaoLocalState extends State<TelaSugestaoLocal> {
  late final LocationsRepository _repositorio;
  late final List<UsuarioResumo> _participantes;

  _ModoSugestao _modo = _ModoSugestao.todos;
  final Set<int> _selecionados = <int>{};
  int? _umId;
  ResultadoSugestoes? _resultado;
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final auth = widget.authController;
    _repositorio = LocationsRepository(
      tokenProvider: () async => auth.sessao?.token,
      onUnauthorized: auth.tratarNaoAutorizado,
    );

    final usuario = auth.usuario;
    _participantes = [
      if (usuario != null)
        UsuarioResumo(
          id: usuario.id,
          nome: usuario.nome,
          username: usuario.username,
        ),
      for (final amigo in widget.amigos)
        if (widget.convidadosSelecionados.contains(amigo.usuario.id))
          amigo.usuario,
    ];
    _selecionados.addAll(_participantes.map((pessoa) => pessoa.id));
    _umId = _participantes.isEmpty ? null : _participantes.first.id;
    _buscar();
  }

  Future<void> _buscar() async {
    final ids = _idsSelecionados();
    if (ids.isEmpty) {
      setState(() => _erro = 'Selecione ao menos uma pessoa.');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final resultado = await _repositorio.sugerirLocais(ids, _modo.name);
      if (!mounted) return;
      setState(() => _resultado = resultado);
    } on ApiException catch (erro) {
      if (!mounted) return;
      setState(() {
        _resultado = null;
        _erro = erro.message;
      });
    } catch (erro) {
      if (mounted) {
        setState(() {
          _resultado = null;
          _erro = 'Não foi possível calcular as sugestões: $erro';
        });
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<int> _idsSelecionados() {
    switch (_modo) {
      case _ModoSugestao.todos:
        return _participantes.map((pessoa) => pessoa.id).toList();
      case _ModoSugestao.alguns:
        return _selecionados.toList();
      case _ModoSugestao.um:
        return _umId == null ? const [] : [_umId!];
    }
  }

  void _mudarModo(_ModoSugestao modo) {
    setState(() {
      _modo = modo;
      _resultado = null;
      _erro = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sugerir local')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AvisoPlacez(
            'Escolha a referência de proximidade. O cálculo usa a localização '
            'aproximada de cada pessoa; nenhuma coordenada individual é '
            'exibida.',
            icone: Icons.shield_outlined,
          ),
          const SizedBox(height: PlacezTokens.espMd),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerLow,
            child: RadioGroup<_ModoSugestao>(
              groupValue: _modo,
              onChanged: (valor) {
                if (valor != null) _mudarModo(valor);
              },
              child: Column(
                children: const [
                  RadioListTile<_ModoSugestao>(
                    value: _ModoSugestao.todos,
                    title: Text('Perto de todos os participantes'),
                    subtitle: Text('Organizador e convidados selecionados.'),
                  ),
                  RadioListTile<_ModoSugestao>(
                    value: _ModoSugestao.alguns,
                    title: Text('Perto de alguns participantes'),
                    subtitle: Text('Escolha um subconjunto.'),
                  ),
                  RadioListTile<_ModoSugestao>(
                    value: _ModoSugestao.um,
                    title: Text('Perto de uma pessoa'),
                    subtitle: Text('Organizador ou um dos convidados.'),
                  ),
                ],
              ),
            ),
          ),
          if (_modo == _ModoSugestao.alguns) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final pessoa in _participantes)
                  FilterChip(
                    label: Text(pessoa.nome),
                    selected: _selecionados.contains(pessoa.id),
                    onSelected: (selecionado) {
                      setState(() {
                        if (selecionado) {
                          _selecionados.add(pessoa.id);
                        } else {
                          _selecionados.remove(pessoa.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
          if (_modo == _ModoSugestao.um) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: theme.colorScheme.surfaceContainerLow,
              child: RadioGroup<int>(
                groupValue: _umId,
                onChanged: (valor) => setState(() => _umId = valor),
                child: Column(
                  children: [
                    for (final pessoa in _participantes)
                      RadioListTile<int>(
                        value: pessoa.id,
                        title: Text(pessoa.nome),
                        subtitle: Text(pessoa.identificador),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _carregando ? null : _buscar,
            icon: _carregando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.place_outlined),
            label: const Text('Buscar sugestões'),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(
              _erro!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_resultado != null) ...[
            if (_resultado!.semLocalizacao.isNotEmpty) ...[
              const SizedBox(height: PlacezTokens.espMd),
              AvisoPlacez(
                'Sem localização aproximada: '
                '${_resultado!.semLocalizacao.map((pessoa) => pessoa.nome).join(', ')}.',
              ),
            ],
            if (_resultado!.localizacoesAproximadas.isNotEmpty) ...[
              const SizedBox(height: PlacezTokens.espLg),
              const TituloSecao('Localizações aproximadas'),
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    for (final pessoa in _resultado!.localizacoesAproximadas)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_city_outlined),
                        title: Text(pessoa.nome),
                        subtitle: Text(
                          [
                            pessoa.localizacao.bairro,
                            pessoa.localizacao.cidade,
                          ].whereType<String>().join(' · '),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: PlacezTokens.espLg),
            const TituloSecao('Sugestões'),
            if (_resultado!.sugestoes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Nenhum lugar encontrado.')),
              )
            else
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    for (final sugestao in _resultado!.sugestoes)
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(sugestao.lugar.rotulo),
                        subtitle: Text(
                          [
                            sugestao.lugar.endereco,
                            sugestao.lugar.cidade,
                          ].whereType<String>().join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          formatarDistancia(
                            sugestao.distanciaMediaMetros.toDouble(),
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                        onTap: () => Navigator.of(context).pop(sugestao.lugar),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
