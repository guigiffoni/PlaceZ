import 'package:flutter/material.dart';

import '../tema.dart';

class TelaSobre extends StatelessWidget {
  const TelaSobre({super.key});

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
                  const SizedBox(height: PlacezTokens.espSm),
                  Text(
                    'Guilherme Amaral Giffoni\nRodrigo Fernandes\nPedro Henrique',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
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
          const SizedBox(height: PlacezTokens.espXl),
          Center(
            child: Text(
              'MIT License',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
