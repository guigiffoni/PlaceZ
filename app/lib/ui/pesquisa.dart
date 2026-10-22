import 'package:flutter/material.dart';

class Pesquisa extends StatefulWidget {
  const Pesquisa({super.key});

  @override
  State<Pesquisa> createState() => _PesquisaState();
}

class _PesquisaState extends State<Pesquisa> {
  final _controller = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onBusca);
  }

  void _onBusca() {
    setState(() => _termoBusca = _controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onBusca);
    _controller.dispose();
    super.dispose();
  }

  final List<Lugar> restaurantes = [
    Lugar(
      nome: "Cantina do Nonno",
      descricao: "Massas artesanais italianas feitas na hora, com receitas de família.",
      avaliacao: 4.7,
    ),
    Lugar(
      nome: "Sushi Yamato",
      descricao: "Culinária japonesa tradicional com peixes frescos importados diariamente.",
      avaliacao: 4.9,
    ),
    Lugar(
      nome: "Boteco da Esquina",
      descricao: "Petiscos brasileiros, chope gelado e música ao vivo nos fins de semana.",
      avaliacao: 4.3,
    ),
    Lugar(
      nome: "Verde Vivo",
      descricao:
          "Cozinha vegana orgânica com ingredientes de produtores locais.",
      avaliacao: 4.5,
    ),
    Lugar(
      nome: "Churrascaria Gaúcha",
      descricao:
          "Cortes nobres na brasa, rodízio completo e buffet de saladas.",
      avaliacao: 4.8,
    ),
    Lugar(
      nome: "Taco Loco",
      descricao:
          "Comida de rua mexicana autêntica, tacos, burritos e margaritas.",
      avaliacao: 4.4,
    ),
    Lugar(
      nome: "Padaria Pão Quente",
      descricao: "Pães artesanais, doces caseiros e café coado na hora todas as manhãs.",
      avaliacao: 4.6,
    ),
    Lugar(
      nome: "Curry & Cia",
      descricao:
          "Pratos indianos apimentados com especiarias importadas de Mumbai.",
      avaliacao: 4.2,
    ),
    Lugar(
      nome: "Casa do Feijão",
      descricao:
          "Comida mineira caseira com feijão tropeiro, tutu e couve refogada.",
      avaliacao: 4.8,
    ),
    Lugar(
      nome: "Bistrô Français",
      descricao: "Alta gastronomia francesa com menu degustação e carta de vinhos selecionados.",
      avaliacao: 4.9,
    ),
    Lugar(
      nome: "Pastelaria Central",
      descricao:
          "Pastéis crocantes fritos na hora, caldo de cana e sucos naturais.",
      avaliacao: 4.1,
    ),
    Lugar(
      nome: "Açaí do Norte",
      descricao:
          "Açaí cremoso com frutas frescas, granola e complementos variados.",
      avaliacao: 4.5,
    ),
    Lugar(
      nome: "Pizzaria Bella Napoli",
      descricao: "Pizzas napolitanas assadas em forno a lenha com massa de fermentação natural.",
      avaliacao: 4.7,
    ),
    Lugar(
      nome: "Sopa & Cia",
      descricao:
          "Sopas cremosas e caldos reconfortantes, perfeitos para dias frios.",
      avaliacao: 4.0,
    ),
    Lugar(
      nome: "Burger Artesanal",
      descricao: "Hambúrgueres gourmet com blend bovino, pão brioche e batatas rústicas.",
      avaliacao: 4.6,
    ),
    Lugar(
      nome: "Doceria Sonho Doce",
      descricao: "Bolos, tortas e sobremesas finas feitas diariamente com ingredientes premium.",
      avaliacao: 4.9,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.all(8.0),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            separatorBuilder: (context, index) => SizedBox(height: 10),
            itemCount: restaurantes.length,
            itemBuilder: (context, index) => LugarPesquisa(restaurantes[index]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(35)),
              ),
              // suffixIcon: Icon(Icons.search)
            ),
            autofocus: true,
            controller: _controller,
          ),
        ),
      ],
    );
  }
}

class Lugar {
  final String nome;
  final String descricao;
  final double avaliacao;

  const Lugar({
    required this.nome,
    required this.descricao,
    required this.avaliacao,
  });
}

class LugarPesquisa extends StatelessWidget {
  const LugarPesquisa(this.lugar, {super.key});

  final Lugar lugar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Padding(
        padding: EdgeInsetsGeometry.all(8.0),
        child: Row(
          spacing: 8.0,
          children: [
            Expanded(child: Icon(Icons.table_bar)),
            Expanded(
              flex: 6,
              child: InfoEstabelecimento(
                nome: lugar.nome,
                descricao: lugar.descricao,
              ),
            ),
            AvaliacaoEstrela(lugar.avaliacao),
          ],
        ),
      ),
    );
  }
}

class InfoEstabelecimento extends StatelessWidget {
  const InfoEstabelecimento({
    required this.nome,
    required this.descricao,
    super.key,
  });

  final String nome;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nome, overflow: TextOverflow.fade, maxLines: 1),
        Text(descricao, overflow: TextOverflow.ellipsis, maxLines: 2),
      ],
    );
  }
}

class AvaliacaoEstrela extends StatelessWidget {
  const AvaliacaoEstrela(this.avaliacao, {super.key});

  final double avaliacao;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topRight,
      child: Row(
        children: [
          Text(
            avaliacao.toStringAsPrecision(2),
            style: TextStyle(color: Colors.yellow.shade900),
          ),
          Icon(Icons.star, color: Colors.yellow.shade600),
        ],
      ),
    );
  }
}
