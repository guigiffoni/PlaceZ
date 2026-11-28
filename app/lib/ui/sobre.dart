import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tema.dart';
import 'telas/licenca.dart';
import 'telas/politica_privacidade.dart';
import 'telas/termos_uso.dart';

class TelaSobre extends StatelessWidget {
  const TelaSobre({super.key});

  static const List<({String nome, String usuario, String url})> _integrantes =
      [
        (
          nome: 'Guilherme Amaral Giffoni',
          usuario: 'guigiffoni',
          url: 'https://github.com/guigiffoni',
        ),
        (
          nome: 'Pedro Henrique Ferreira',
          usuario: 'Pe2211',
          url: 'https://github.com/Pe2211',
        ),
        (
          nome: 'Rodrigo Fernandes Moraes',
          usuario: 'rodrigofmn25',
          url: 'https://github.com/rodrigofmn25',
        ),
      ];

  Future<void> _abrirUrl(BuildContext context, String url) async {
    try {
      final abriu = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!abriu && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o PlaceZ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: PlacezTokens.bordaLg,
              child: Image.asset(
                'assets/logo_principal.jpg',
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: PlacezTokens.espXl),
          Text(
            'Encontros mais fáceis entre amigos',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: PlacezTokens.espSm),
          Text(
            'O PlaceZ auxilia grupos na organização de encontros e eventos, '
            'permitindo consultar lugares, combinar datas e conversar com os '
            'participantes.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PlacezTokens.espXl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PlacezTokens.espLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: PlacezTokens.espSm),
                      Text(
                        'Projeto acadêmico',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PlacezTokens.espSm),
                  Text(
                    'Criado no segundo semestre de 2026 para a disciplina de '
                    'Desenvolvimento Móvel, com o intuito de facilitar o '
                    'encontro entre amigos.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PlacezTokens.espMd),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PlacezTokens.espLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: PlacezTokens.espSm),
                      Text(
                        'Desenvolvido por',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  for (final integrante in _integrantes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        child: const Icon(Icons.code, size: 18),
                      ),
                      title: Text(integrante.nome),
                      subtitle: Text('github.com/${integrante.usuario}'),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _abrirUrl(context, integrante.url),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PlacezTokens.espLg),
          Text(
            'Fotos ilustrativas do catálogo: Unsplash.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PlacezTokens.espLg),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Termos de Uso'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TelaTermosUso(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Política de Privacidade'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TelaPoliticaPrivacidade(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Licença MIT'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TelaLicenca(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
