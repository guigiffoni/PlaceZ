import 'package:flutter/material.dart';

import '../widgets/documento_legal.dart';

class TelaTermosUso extends StatelessWidget {
  const TelaTermosUso({super.key});

  @override
  Widget build(BuildContext context) {
    return const TelaDocumentoLegal(
      titulo: 'Termos de Uso',
      atualizadoEm: 'Última atualização: 27 de novembro de 2026',
      secoes: [
        SecaoLegal('1. Aceitação', [
          'Ao acessar ou usar o PlaceZ, você declara que leu e concorda com '
              'estes Termos de Uso e com a Política de Privacidade. Se não '
              'concordar, não utilize o aplicativo.',
        ]),
        SecaoLegal('2. Finalidade do aplicativo', [
          'O PlaceZ é um projeto acadêmico desenvolvido para a disciplina de '
              'Desenvolvimento Móvel. Ele auxilia na organização de encontros, '
              'eventos, combinações de datas, escolha de locais e conversas '
              'entre amigos.',
        ]),
        SecaoLegal('3. Conta e segurança', [
          'Você é responsável pelas informações fornecidas e por manter a '
              'confidencialidade da sua senha. As atividades realizadas na sua '
              'conta são de sua responsabilidade. Comunique imediatamente '
              'qualquer uso não autorizado.',
        ]),
        SecaoLegal('4. Uso adequado', [
          'É proibido usar o aplicativo para assédio, ameaça, discriminação, '
              'spam, conteúdo ilegal, violação de direitos de terceiros, '
              'tentativa de acesso indevido, automação abusiva ou qualquer '
              'ação que prejudique o serviço ou outros usuários.',
        ]),
        SecaoLegal('5. Conteúdo do usuário', [
          'Você mantém a titularidade dos textos, fotos e demais conteúdos que '
              'envia. Ao enviar conteúdo, você concede ao PlaceZ uma licença '
              'limitada para armazenar, processar e exibir esse conteúdo apenas '
              'para o funcionamento do aplicativo. Não envie conteúdo de '
              'terceiros sem autorização.',
        ]),
        SecaoLegal('6. Eventos e encontros presenciais', [
          'O PlaceZ apenas facilita a organização. Não verificamos a identidade '
              'dos participantes, a segurança dos locais ou a realização dos '
              'encontros. A participação em eventos presenciais é de sua '
              'responsabilidade.',
        ]),
        SecaoLegal('7. Localização', [
          'A localização é opcional e aproximada. O aplicativo não usa '
              'rastreamento em tempo real nem em segundo plano e não divulga '
              'coordenadas exatas para outros usuários. Você pode remover sua '
              'localização a qualquer momento em Configurações.',
        ]),
        SecaoLegal('8. Disponibilidade e alterações', [
          'O serviço é acadêmico e pode ficar indisponível, mudar ou ser '
              'encerrado. Podemos ajustar funcionalidades e estes termos. A '
              'data de atualização será alterada quando houver mudanças '
              'relevantes.',
        ]),
        SecaoLegal('9. Propriedade intelectual', [
          'O código-fonte está licenciado sob a MIT License. A marca, o layout, '
              'os textos e os elementos visuais do PlaceZ pertencem aos '
              'integrantes do projeto. As fotos ilustrativas do catálogo são de '
              'terceiros e mantêm suas próprias licenças.',
        ]),
        SecaoLegal('10. Limitação de responsabilidade', [
          'Na medida permitida pela lei, o PlaceZ e seus integrantes não se '
              'responsabilizam por danos indiretos, imprecisões de localização, '
              'indisponibilidade do serviço, condutas de outros usuários ou '
              'encontros realizados a partir do aplicativo.',
        ]),
        SecaoLegal('11. Encerramento', [
          'Podemos suspender ou encerrar contas que violem estes termos. Você '
              'pode deixar de usar o aplicativo a qualquer momento e solicitar '
              'a exclusão dos seus dados pelos canais de contato.',
        ]),
        SecaoLegal('12. Contato', [
          'Dúvidas podem ser encaminhadas aos desenvolvedores pelos perfis do '
              'GitHub disponíveis na tela Sobre. Estes termos podem ser '
              'atualizados; a versão vigente é a exibida no aplicativo.',
        ]),
      ],
      avisoFinal:
          'Este documento foi elaborado para um projeto acadêmico e não '
          'substitui uma análise jurídica profissional.',
    );
  }
}
