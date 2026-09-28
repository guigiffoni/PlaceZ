import 'package:flutter/material.dart';

class TelaCalendario extends StatefulWidget {
  const TelaCalendario({super.key});

  @override
  State<TelaCalendario> createState() => _TelaCalendarioState();
}

class _TelaCalendarioState extends State<TelaCalendario> {
  DateTime mesAtual = DateTime.now();

  final List<DateTime> diasSelecionados = [];

  final List<String> pessoas = [];

  bool diaEstaSelecionado(DateTime data) {
    return diasSelecionados.any(
      (dia) =>
          dia.day == data.day &&
          dia.month == data.month &&
          dia.year == data.year,
    );
  }

  void selecionarDia(DateTime data) {
    setState(() {
      if (diaEstaSelecionado(data)) {
        diasSelecionados.removeWhere(
          (dia) =>
              dia.day == data.day &&
              dia.month == data.month &&
              dia.year == data.year,
        );
      } else {
        diasSelecionados.add(data);
      }
    });
  }

  String nomeMes(int mes) {
    const meses = [
      "Janeiro",
      "Fevereiro",
      "Março",
      "Abril",
      "Maio",
      "Junho",
      "Julho",
      "Agosto",
      "Setembro",
      "Outubro",
      "Novembro",
      "Dezembro",
    ];

    return meses[mes - 1];
  }

  void adicionarPessoa() {
    final TextEditingController nomeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Adicionar pessoa"),
          content: TextField(
            controller: nomeController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "Nome",
              hintText: "Digite o nome da pessoa",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                String nome = nomeController.text.trim();

                if (nome.isNotEmpty) {
                  setState(() {
                    pessoas.add(nome);
                  });

                  Navigator.pop(context);
                }
              },
              child: const Text("Adicionar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Pessoas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 12),

                OutlinedButton.icon(
                  onPressed: adicionarPessoa,
                  icon: const Icon(
                    Icons.person_add_alt_1,
                    size: 18,
                  ),
                  label: const Text("Adicionar pessoa"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF071369),
                    side: const BorderSide(
                      color: Color(0xFF071369),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                ...pessoas.map(
                  (nome) => participante(
                    nome,
                    const Color(0xFF858CD8),
                  ),
                ),

                const SizedBox(width: 12),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Mês e botões
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    mesAtual = DateTime(
                      mesAtual.year,
                      mesAtual.month - 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),

              Expanded(
                child: Center(
                  child: Text(
                    "${nomeMes(mesAtual.month)} ${mesAtual.year}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              IconButton(
                onPressed: () {
                  setState(() {
                    mesAtual = DateTime(
                      mesAtual.year,
                      mesAtual.month + 1,
                    );
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),

          const SizedBox(height: 5),

          // Dias da semana
          const Row(
            children: [
              Expanded(child: Center(child: Text("DOM"))),
              Expanded(child: Center(child: Text("SEG"))),
              Expanded(child: Center(child: Text("TER"))),
              Expanded(child: Center(child: Text("QUA"))),
              Expanded(child: Center(child: Text("QUI"))),
              Expanded(child: Center(child: Text("SEX"))),
              Expanded(child: Center(child: Text("SÁB"))),
            ],
          ),

          const SizedBox(height: 5),

          // Calendário
          Expanded(
            child: construirCalendario(),
          ),
        ],
      ),
    );
  }

  Widget construirCalendario() {
    int ano = mesAtual.year;
    int mes = mesAtual.month;

    int quantidadeDias = DateTime(
      ano,
      mes + 1,
      0,
    ).day;

    int primeiroDiaSemana = DateTime(
          ano,
          mes,
          1,
        ).weekday %
        7;

    int totalCelulas = primeiroDiaSemana + quantidadeDias;

    int quantidadeSemanas = (totalCelulas / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        double larguraCelula = constraints.maxWidth / 7;

        double alturaCelula =
            constraints.maxHeight / quantidadeSemanas;

        double proporcao = larguraCelula / alturaCelula;

        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: proporcao,
          ),
          itemCount: quantidadeSemanas * 7,
          itemBuilder: (context, index) {
            int numeroDia =
                index - primeiroDiaSemana + 1;

            if (numeroDia < 1 ||
                numeroDia > quantidadeDias) {
              return construirCelulaVazia();
            }

            DateTime data = DateTime(
              ano,
              mes,
              numeroDia,
            );

            return construirDia(
              data,
              numeroDia,
            );
          },
        );
      },
    );
  }

  Widget construirDia(
    DateTime data,
    int numeroDia,
  ) {
    bool selecionado = diaEstaSelecionado(data);

    return GestureDetector(
      onTap: () {
        selecionarDia(data);
      },
      child: Container(
        decoration: BoxDecoration(
          color: selecionado
              ? const Color(0xFFE4E1FF)
              : Colors.white,
          border: Border.all(
            color: const Color(0xFFEEEEEE),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selecionado
                      ? const Color(0xFF071369)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  "$numeroDia",
                  style: TextStyle(
                    fontSize: 12,
                    color: selecionado
                        ? Colors.white
                        : const Color(0xFF555555),
                    fontWeight: selecionado
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),

              // Espaço reservado para eventos futuros
              const Expanded(
                child: SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget construirCelulaVazia() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(
          color: const Color(0xFFEEEEEE),
          width: 0.5,
        ),
      ),
    );
  }

  Widget participante(
    String nome,
    Color cor,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        nome,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }
}