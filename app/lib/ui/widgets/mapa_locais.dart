import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/local.dart';

class MapaLocais extends StatelessWidget {
  final List<Local> locais;

  const MapaLocais({super.key, required this.locais});

  @override
  Widget build(BuildContext context) {
    // Filtra locais que possuem coordenadas válidas
    final locaisComCoordenadas = locais.where(
      (l) => l.latitude != null && l.longitude != null,
    ).toList();

    return FlutterMap(
      options: const MapOptions(
        // Centro inicial (ex: São Paulo). Ajuste conforme seus dados.
        initialCenter: LatLng(-23.5505, -46.6333),
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          // Servidor público do OpenStreetMap
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // Identificação do seu app (obrigatório pelas regras do OSM)
          userAgentPackageName: 'com.example.app',
        ),
        // Camada de marcadores
        MarkerLayer(
          markers: locaisComCoordenadas.map((local) {
            return Marker(
              point: LatLng(local.latitude!, local.longitude!),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  // Ação utilitarista: mostrar o nome do local ao tocar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(local.nome ?? 'Sem nome')),
                  );
                },
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}