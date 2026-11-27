import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SeletorMapa extends StatefulWidget {
  final LatLng? posicaoInicial;
  final bool apenasVisualizacao;

  const SeletorMapa({
    super.key,
    this.posicaoInicial,
    this.apenasVisualizacao = false,
  });

  @override
  State<SeletorMapa> createState() => _SeletorMapaState();
}

class _SeletorMapaState extends State<SeletorMapa> {
  LatLng? _pontoSelecionado;

  @override
  void initState() {
    super.initState();
    // Se recebeu uma posição, ela já começa selecionada
    _pontoSelecionado = widget.posicaoInicial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.apenasVisualizacao
              ? 'Local do Evento'
              : 'Toque no mapa para selecionar',
        ),
        actions: [
          if (!widget.apenasVisualizacao)
            IconButton(
              tooltip: 'Confirmar local',
              onPressed: _pontoSelecionado == null
                  ? null
                  : () => Navigator.pop(context, _pontoSelecionado),
              icon: const Icon(Icons.check),
            ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter:
              widget.posicaoInicial ?? const LatLng(-19.9245, -43.9400),
          initialZoom: 15.0,
          onTap: widget.apenasVisualizacao
              ? null // Se for só visualização, não deixa selecionar
              : (tapPosition, point) {
                  setState(() {
                    _pontoSelecionado = point;
                  });
                },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'br.pucminas.placez',
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
          if (_pontoSelecionado != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _pontoSelecionado!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
        ],
      ),
      // Só mostra o botão de confirmar se for seleção
      floatingActionButton: widget.apenasVisualizacao
          ? null
          : FloatingActionButton(
              onPressed: _pontoSelecionado == null
                  ? null
                  : () => Navigator.pop(context, _pontoSelecionado),
              child: const Icon(Icons.check),
            ),
    );
  }
}
