import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/locations/locations_repository.dart';
import '../../core/locations/nominatim_service.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/localizacao.dart';
import '../../tema.dart';
import '../widgets/placez_componentes.dart';
import '../widgets/seletor_mapa.dart';

class TelaLocalizacaoAproximada extends StatefulWidget {
  final AuthController authController;

  const TelaLocalizacaoAproximada({super.key, required this.authController});

  @override
  State<TelaLocalizacaoAproximada> createState() =>
      _TelaLocalizacaoAproximadaState();
}

class _TelaLocalizacaoAproximadaState extends State<TelaLocalizacaoAproximada> {
  final NominatimService _nominatim = NominatimService();

  late final LocationsRepository _repositorio;
  LocalizacaoUsuario? _localizacao;
  bool _carregando = true;
  bool _ocupado = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final auth = widget.authController;
    _repositorio = LocationsRepository(
      tokenProvider: () async => auth.sessao?.token,
      onUnauthorized: auth.tratarNaoAutorizado,
    );
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final localizacao = await _repositorio.obterMinhaLocalizacao();
      if (!mounted) return;
      setState(() => _localizacao = localizacao);
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erro = erro.message);
    } catch (erro) {
      if (mounted) {
        setState(
          () => _erro = 'Não foi possível carregar a localização: $erro',
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _definirLocal(
    double latitude,
    double longitude,
    String origem,
  ) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _erro = null;
    });

    try {
      final reverso = await _nominatim.reverter(latitude, longitude);
      if (!mounted) return;

      final latitudeAproximada = (latitude * 100).round() / 100;
      final longitudeAproximada = (longitude * 100).round() / 100;
      final confirmou = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Usar esta localização aproximada?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  reverso.bairro,
                  reverso.cidade,
                ].whereType<String>().join(' · '),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Será salvo apenas o bairro e um ponto aproximado '
                '($latitudeAproximada, $longitudeAproximada). '
                'A localização exata não é armazenada.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
      if (confirmou != true || !mounted) return;

      final salva = await _repositorio.salvarLocalizacaoAproximada(
        bairro: reverso.bairro,
        cidade: reverso.cidade,
        latitude: latitudeAproximada,
        longitude: longitudeAproximada,
        origem: origem,
      );
      if (!mounted) return;
      setState(() => _localizacao = salva);
      Navigator.of(context).pop(true);
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erro = erro.message);
    } catch (erro) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível definir o bairro: $erro');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _usarGps() async {
    if (_ocupado) return;
    try {
      final servico = await Geolocator.isLocationServiceEnabled();
      if (!servico) {
        _avisar('Ative a localização do aparelho para usar o GPS.');
        return;
      }

      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        _avisar('Permissão de localização não concedida.');
        return;
      }

      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _definirLocal(posicao.latitude, posicao.longitude, 'GPS');
    } catch (erro) {
      _avisar('Não foi possível obter a localização atual: $erro');
    }
  }

  Future<void> _escolherNoMapa() async {
    if (_ocupado) return;
    final ponto = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (context) => const SeletorMapa()),
    );
    if (ponto == null || !mounted) return;
    await _definirLocal(ponto.latitude, ponto.longitude, 'MAPA');
  }

  Future<void> _buscarEndereco() async {
    if (_ocupado) return;
    final controller = TextEditingController();
    final termo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar endereço'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex.: Praça da Liberdade, Belo Horizonte',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (termo == null || termo.isEmpty || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final resultados = await _nominatim.buscar(termo);
      if (!mounted) return;
      if (resultados.isEmpty) {
        _avisar('Nenhum endereço encontrado.');
        return;
      }

      final escolhido = await showDialog<ResultadoEnderecoNominatim>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resultados'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView.builder(
              itemCount: resultados.length,
              itemBuilder: (context, index) {
                final resultado = resultados[index];
                return ListTile(
                  title: Text(resultado.descricao),
                  onTap: () => Navigator.of(context).pop(resultado),
                );
              },
            ),
          ),
        ),
      );
      if (escolhido == null || !mounted) return;
      setState(() => _ocupado = false);
      await _definirLocal(escolhido.latitude, escolhido.longitude, 'BUSCA');
    } catch (erro) {
      if (mounted) {
        _avisar('Não foi possível buscar o endereço: $erro');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _informarCoordenadas() async {
    if (_ocupado) return;
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();
    final resultado = await showDialog<List<double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informar coordenadas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: '-19.93',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: longitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: '-43.94',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final latitude = double.tryParse(
                latitudeController.text.replaceAll(',', '.').trim(),
              );
              final longitude = double.tryParse(
                longitudeController.text.replaceAll(',', '.').trim(),
              );
              if (latitude == null ||
                  longitude == null ||
                  latitude < -90 ||
                  latitude > 90 ||
                  longitude < -180 ||
                  longitude > 180) {
                return;
              }
              Navigator.of(context).pop([latitude, longitude]);
            },
            child: const Text('Usar'),
          ),
        ],
      ),
    );
    latitudeController.dispose();
    longitudeController.dispose();

    if (resultado == null || resultado.length != 2 || !mounted) return;
    await _definirLocal(resultado[0], resultado[1], 'COORDENADAS');
  }

  Future<void> _remover() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Não divulgar localização?'),
        content: const Text(
          'Ela deixará de aparecer para seus amigos e não será usada nas '
          'sugestões de locais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Não divulgar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await _repositorio.removerLocalizacao();
      if (!mounted) return;
      setState(() => _localizacao = null);
      Navigator.of(context).pop(true);
    } on ApiException catch (erro) {
      if (mounted) setState(() => _erro = erro.message);
    } catch (erro) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível remover a localização: $erro');
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
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
    final localizacao = _localizacao;

    return Scaffold(
      appBar: AppBar(title: const Text('Localização')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const AvisoPlacez(
                  'Sua localização exata não é armazenada. O app salva apenas '
                  'o bairro e um ponto aproximado, usado para sugerir locais. '
                  'Amigos e o organizador do evento veem somente a localização '
                  'aproximada.',
                  icone: Icons.shield_outlined,
                ),
                const SizedBox(height: PlacezTokens.espLg),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: theme.colorScheme.surfaceContainerLow,
                  child: ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: Text(
                      localizacao == null
                          ? 'Não divulgada'
                          : 'Aproximada via ${localizacao.origemRotulo}',
                    ),
                    subtitle: Text(
                      localizacao == null
                          ? 'Nenhuma localização aproximada está visível.'
                          : [
                              localizacao.bairro,
                              if (localizacao.cidade != null)
                                localizacao.cidade!,
                              if (localizacao.legado) 'atualize se quiser',
                              if (localizacao.latitude != null &&
                                  localizacao.longitude != null)
                                '${localizacao.latitude}, '
                                    '${localizacao.longitude}',
                            ].join(' · '),
                    ),
                  ),
                ),
                if (_ocupado) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                _acao(
                  icon: Icons.my_location,
                  titulo: 'Usar minha localização atual',
                  subtitulo: 'Captura única via GPS; sem rastreamento.',
                  onTap: _ocupado ? null : _usarGps,
                ),
                _acao(
                  icon: Icons.map_outlined,
                  titulo: 'Escolher no mapa',
                  subtitulo: 'Toque no mapa em qualquer ponto.',
                  onTap: _ocupado ? null : _escolherNoMapa,
                ),
                _acao(
                  icon: Icons.search,
                  titulo: 'Buscar endereço',
                  subtitulo: 'Pesquisa via Nominatim.',
                  onTap: _ocupado ? null : _buscarEndereco,
                ),
                _acao(
                  icon: Icons.pin_drop_outlined,
                  titulo: 'Informar latitude/longitude',
                  subtitulo: 'Digite as coordenadas do ponto desejado.',
                  onTap: _ocupado ? null : _informarCoordenadas,
                ),
                if (localizacao != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _ocupado ? null : _remover,
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('Não divulgar localização'),
                  ),
                ],
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _acao({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Icon(icon),
        title: Text(titulo),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
