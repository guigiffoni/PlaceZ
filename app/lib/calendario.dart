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
    final TextEditingController nomeController =
        TextEditingController();

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
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 25),

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
                    label: const Text(
                      "Adicionar pessoa",
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          const Color(0xFF071369),
                      side: const BorderSide(
                        color: Color(0xFF071369),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(7),
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

            Expanded(
              child: Center(
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                    ),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                            icon: const Icon(
                              Icons.chevron_left,
                              size: 20,
                            ),
                          ),

                          Expanded(
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                caixaSelecao(
                                  nomeMes(
                                    mesAtual.month,
                                  ),
                                ),

                                const SizedBox(width: 8),

                                caixaSelecao(
                                  mesAtual.year.toString(),
                                ),
                              ],
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
                            icon: const Icon(
                              Icons.chevron_right,
                              size: 20,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      const Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                "Dom",
                                style: TextStyle(
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "Seg",
                                style: TextStyle(
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "Ter",
                                style: TextStyle(
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "Qua",
                                style: TextStyle(
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "Qui",
                                style: TextStyle(
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "Sex",
                                style: TextStyle(
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "Sáb",
                                style: TextStyle(
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      construirCalendario(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),);
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

    List<Widget> dias = [];

    for (
      int i = 0;
      i < primeiroDiaSemana;
      i++
    ) {
      dias.add(
        const SizedBox(
          width: 32,
          height: 32,
        ),
      );
    }

    for (
      int dia = 1;
      dia <= quantidadeDias;
      dia++
    ) {
      DateTime data = DateTime(
        ano,
        mes,
        dia,
      );

      dias.add(
        construirDia(data),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
      children: dias,
    );
  }

  Widget construirDia(DateTime data) {
    bool selecionado =
        diaEstaSelecionado(data);

    return GestureDetector(
      onTap: () {
        selecionarDia(data);
      },

      child: Container(
        alignment: Alignment.center,

        decoration: BoxDecoration(
          color: selecionado
              ? const Color(0xFF071369)
              : Colors.transparent,

          borderRadius:
              BorderRadius.circular(6),
        ),

        child: Text(
          data.day.toString(),

          style: TextStyle(
            color: selecionado
                ? Colors.white
                : Colors.black,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget participante(
    String nome,
    Color cor,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        right: 5,
      ),

      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color: cor,
        borderRadius:
            BorderRadius.circular(5),
      ),

      child: Text(
        nome,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget caixaSelecao(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),

      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFFD6D6D6),
        ),
        borderRadius:
            BorderRadius.circular(5),
      ),

      child: Row(
        children: [
          Text(
            texto,
            style: const TextStyle(
              fontSize: 11,
            ),
          ),

          const SizedBox(width: 5),

          const Icon(
            Icons.keyboard_arrow_down,
            size: 14,
          ),
        ],
      ),
    );
  }
}