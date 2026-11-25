import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_mode.dart';
import '../../core/network/api_preferences.dart';

class DiagnosticoApi extends StatefulWidget {
  const DiagnosticoApi({super.key});

  @override
  State<DiagnosticoApi> createState() => _DiagnosticoApiState();
}

class _DiagnosticoApiState extends State<DiagnosticoApi> {
  ApiMode? _modo;
  bool _testando = false;
  String? _resultado;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _carregarModo();
  }

  Future<void> _carregarModo() async {
    final modo = await ApiPreferences.carregaModo();
    if (!mounted) return;
    setState(() => _modo = modo);
  }

  Future<void> _alterarModo(ApiMode modo) async {
    setState(() {
      _modo = modo;
      _resultado = null;
      _erro = false;
    });
    await ApiPreferences.salvaModo(modo);
  }

  Future<void> _testar() async {
    final modo = _modo;
    if (modo == null || _testando) return;

    setState(() {
      _testando = true;
      _resultado = null;
      _erro = false;
    });

    final client = ApiClient(mode: modo);
    try {
      final resposta = await client.get('/health');
      if (!mounted) return;
      setState(() {
        _resultado = _formataResposta(resposta);
        _erro = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _resultado = erro.toString();
        _erro = true;
      });
    } finally {
      client.close();
      if (mounted) setState(() => _testando = false);
    }
  }

  String _formataResposta(dynamic resposta) {
    if (resposta is Map) {
      final status = resposta['status'] ?? 'desconhecido';
      final db = resposta['db'] ?? 'desconhecido';
      final mode = resposta['mode'];
      final sufixo = mode == null ? '' : ' · modo $mode';
      return 'status: $status · db: $db$sufixo';
    }
    return resposta?.toString() ?? 'resposta vazia';
  }

  @override
  Widget build(BuildContext context) {
    final modo = _modo;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conexão com a API',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (modo == null)
          const LinearProgressIndicator()
        else ...[
          SegmentedButton<ApiMode>(
            segments: ApiMode.values
                .map(
                  (item) => ButtonSegment<ApiMode>(
                    value: item,
                    label: Text(item.label),
                    icon: Icon(
                      item == ApiMode.mock ? Icons.storage : Icons.cloud,
                    ),
                  ),
                )
                .toList(),
            selected: {modo},
            onSelectionChanged: (selecao) => _alterarModo(selecao.first),
          ),
          const SizedBox(height: 8),
          Text(
            modo == ApiMode.mock
                ? 'Fonte: JSON local em ${ApiConfig.mockAsset}'
                : 'Base URL: ${ApiConfig.baseUrl}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _testando ? null : _testar,
            icon: _testando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: const Text('Testar /health'),
          ),
          if (_resultado != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _erro
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _resultado!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _erro ? theme.colorScheme.onErrorContainer : null,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
