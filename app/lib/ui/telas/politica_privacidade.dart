import 'package:flutter/material.dart';

import '../widgets/documento_legal.dart';

class TelaPoliticaPrivacidade extends StatelessWidget {
  const TelaPoliticaPrivacidade({super.key});

  @override
  Widget build(BuildContext context) {
    return const TelaDocumentoLegal(
      titulo: 'Política de Privacidade',
      atualizadoEm: 'Última atualização: 27 de novembro de 2026',
      secoes: [
        SecaoLegal('1. Escopo', [
          'Esta política explica como o PlaceZ coleta, usa, armazena e '
              'compartilha dados. O PlaceZ é um projeto acadêmico da '
              'disciplina de Desenvolvimento Móvel.',
        ]),
        SecaoLegal('2. Dados coletados', [
          'Cadastro: nome, username, senha armazenada como hash e foto de '
              'perfil opcional.',
          'Perfil: localização aproximada opcional (bairro, cidade e '
              'coordenada arredondada) e amigos favoritos.',
          'Uso: eventos, descrições, datas, locais, imagens de eventos, '
              'convites, respostas de presença, grupos, mensagens, avaliações '
              'e comentários de lugares.',
          'Dados técnicos: datas de criação e atualização, identificadores de '
              'sessão e registros necessários para segurança.',
        ]),
        SecaoLegal('3. Como usamos os dados', [
          'Usamos os dados para autenticar sua conta, exibir e organizar '
              'eventos, calcular distâncias e sugerir locais, permitir '
              'conversas, mostrar avaliações, manter a segurança e atender '
              'solicitações relacionadas ao aplicativo.',
        ]),
        SecaoLegal('4. Localização', [
          'A localização é opcional, aproximada e capturada apenas quando você '
              'escolhe usar GPS, mapa, busca de endereço ou coordenadas. O '
              'aplicativo arredonda a coordenada e não armazena o ponto exato. '
              'Não há rastreamento contínuo nem em segundo plano.',
          'Amigos e organizadores de eventos veem apenas o bairro e a cidade. '
              'As distâncias são calculadas a partir da localização aproximada. '
              'Você pode remover a localização em Configurações.',
        ]),
        SecaoLegal('5. Compartilhamento', [
          'Seu perfil pode ser visto por amigos. Eventos são visíveis para o '
              'criador e para os convidados; eventos privados não aparecem para '
              'não convidados. Mensagens são visíveis aos participantes da '
              'conversa. Não vendemos dados pessoais.',
        ]),
        SecaoLegal('6. Serviços de terceiros', [
          'A busca de endereço usa Nominatim/OpenStreetMap e envia o texto '
              'pesquisado a esse serviço. Ao abrir um mapa, o aplicativo pode '
              'abrir Google Maps ou OpenStreetMap, sujeitos às políticas desses '
              'serviços.',
          'As fotos ilustrativas do catálogo são de Unsplash e ficam embutidas '
              'no aplicativo, sem envio de dados do usuário para esse serviço.',
        ]),
        SecaoLegal('7. Armazenamento e segurança', [
          'Os dados são armazenados em banco Oracle em servidor do projeto. '
              'Adotamos controle de acesso, hash de senhas e validações de '
              'entrada. Nenhum sistema é totalmente seguro; evite enviar dados '
              'sensíveis desnecessários.',
        ]),
        SecaoLegal('8. Retenção', [
          'Os dados são mantidos enquanto a conta existir ou enquanto forem '
              'necessários para operar o aplicativo. Mensagens e eventos podem '
              'permanecer para os demais participantes. Solicitações de '
              'exclusão serão avaliadas pelos responsáveis pelo projeto.',
        ]),
        SecaoLegal('9. Seus direitos (LGPD)', [
          'Você pode solicitar confirmação de tratamento, acesso, correção, '
              'anonimização, bloqueio ou eliminação, portabilidade, informação '
              'sobre compartilhamento e revogação de consentimento. Use os '
              'canais de contato indicados na tela Sobre.',
        ]),
        SecaoLegal('10. Crianças e adolescentes', [
          'O aplicativo não é destinado a menores de 18 anos sem supervisão de '
              'um responsável. Se identificarmos uso indevido, os dados poderão '
              'ser removidos.',
        ]),
        SecaoLegal('11. Alterações', [
          'Esta política pode ser atualizada. A data de atualização será '
              'alterada quando houver mudanças relevantes.',
        ]),
        SecaoLegal('12. Contato', [
          'Fale com os desenvolvedores pelos perfis do GitHub disponíveis na '
              'tela Sobre.',
        ]),
      ],
      avisoFinal:
          'Esta política foi elaborada para um projeto acadêmico e não '
          'substitui uma análise jurídica profissional.',
    );
  }
}
