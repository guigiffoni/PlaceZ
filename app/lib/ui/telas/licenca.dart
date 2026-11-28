import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../tema.dart';

class TelaLicenca extends StatelessWidget {
  const TelaLicenca({super.key});

  static const String _texto = '''MIT License

Copyright (c) 2026 Guilherme Amaral Giffoni, Pedro Henrique Ferreira, Rodrigo Fernandes Moraes

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

  Future<void> _abrirOficial(BuildContext context) async {
    final uri = Uri.parse('https://opensource.org/license/mit');
    try {
      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abriu && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir a licença oficial.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir a licença oficial.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Licença MIT')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Licença MIT',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PlacezTokens.espXs),
          Text(
            'Copyright (c) 2026 Guilherme Amaral Giffoni, Pedro Henrique Ferreira, Rodrigo Fernandes Moraes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PlacezTokens.espLg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PlacezTokens.espLg),
              child: SelectableText(
                _texto,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
            ),
          ),
          const SizedBox(height: PlacezTokens.espLg),
          OutlinedButton.icon(
            onPressed: () => _abrirOficial(context),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Ver licença oficial'),
          ),
        ],
      ),
    );
  }
}
