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
          title: const Text(
            "Adicionar pessoa",
          ),
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
              child: const Text(
                "Cancelar",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                String nome =
                    nomeController.text.trim();

                if (nome.isNotEmpty) {
                  setState(() {
                    pessoas.add(nome);
                  });

                  Navigator.pop(context);
                }
              },
              child: const Text(
                "Adicionar",
              ),
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
            const SizedBox(height: 12),

            // PARTICIPANTES
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

            const SizedBox(height: 10),

            // CABEÇALHO DO CALENDÁRIO
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Row(
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
                      size: 26,
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: Text(
                        "${nomeMes(mesAtual.month)} ${mesAtual.year}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w600,
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
                    icon: const Icon(
                      Icons.chevron_right,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            // DIAS DA SEMANA
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        "DOM",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "SEG",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "TER",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "QUA",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "QUI",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "SEX",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "SÁB",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            const Divider(
              height: 1,
              color: Color(0xFFE5E5E5),
            ),

            // CALENDÁRIO
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                child: construirCalendario(),
              ),
            ),
          ],
        ),
      ),

      // BARRA DE NAVEGAÇÃO INFERIOR
      bottomNavigationBar: Container(
        color: const Color(0xFFFCF4FF),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                // CALENDÁRIO
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFFEC7B8C),
                  size: 22,
                ),

                // CHAT
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: Color(0xFF404040),
                      ),
                    ),

                    Positioned(
                      right: 1,
                      top: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        alignment:
                            Alignment.center,
                        decoration:
                            const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          "7",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // BUSCA
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.search,
                    color: Color(0xFF404040),
                    size: 22,
                  ),
                ),

                // PERFIL
                const CircleAvatar(
                  radius: 17,
                  backgroundColor:
                      Color(0xFFDDDDDD),
                  child: Icon(
                    Icons.person,
                    color: Color(0xFF303030),
                    size: 20,
                  ),
                ),

                // ADICIONAR EVENTO
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFFF2424),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget construirCalendario() {
    int ano = mesAtual.year;
    int mes = mesAtual.month;

    // DESCOBRE QUANTOS DIAS O MÊS POSSUI
    int quantidadeDias = DateTime(
      ano,
      mes + 1,
      0,
    ).day;

    // DESCOBRE EM QUAL DIA DA SEMANA
    // O PRIMEIRO DIA DO MÊS COMEÇA
    int primeiroDiaSemana = DateTime(
          ano,
          mes,
          1,
        ).weekday %
        7;

    int quantidadeCelulas =
        primeiroDiaSemana +
        quantidadeDias;

    // DESCOBRE QUANTAS SEMANAS
    // PRECISAMOS MOSTRAR
    int quantidadeSemanas =
        (quantidadeCelulas / 7).ceil();

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        // ALTURA DISPONÍVEL DIVIDIDA
        // PELA QUANTIDADE DE SEMANAS
        double alturaCelula =
            constraints.maxHeight /
            quantidadeSemanas;

        // LARGURA DIVIDIDA PELOS
        // SETE DIAS DA SEMANA
        double larguraCelula =
            constraints.maxWidth / 7;

        double proporcao =
            larguraCelula /
            alturaCelula;

        return GridView.builder(
          physics:
              const NeverScrollableScrollPhysics(),

          padding: EdgeInsets.zero,

          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio:
                proporcao,
          ),

          itemCount:
              quantidadeSemanas * 7,

          itemBuilder: (
            context,
            index,
          ) {
            int numeroDia =
                index -
                primeiroDiaSemana +
                1;

            // ESPAÇOS VAZIOS ANTES OU
            // DEPOIS DOS DIAS DO MÊS
            if (numeroDia < 1 ||
                numeroDia >
                    quantidadeDias) {
              return construirCelulaVazia();
            }

            DateTime data = DateTime(
              ano,
              mes,
              numeroDia,
            );

            return construirDia(
              data,
            );
          },
        );
      },
    );
  }

  Widget construirDia(
    DateTime data,
  ) {
    bool selecionado =
        diaEstaSelecionado(data);

    return GestureDetector(
      onTap: () {
        selecionarDia(data);
      },

      child: Container(
        decoration: BoxDecoration(
          color: selecionado
              ? const Color(0xFFE8E9FF)
              : Colors.white,

          border: Border.all(
            color:
                const Color(0xFFEEEEEE),
            width: 0.5,
          ),
        ),

        child: Padding(
          padding:
              const EdgeInsets.all(5),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // NÚMERO DO DIA
              Container(
                width: 27,
                height: 27,
                alignment:
                    Alignment.center,

                decoration: BoxDecoration(
                  color: selecionado
                      ? const Color(
                          0xFF071369,
                        )
                      : Colors.transparent,

                  shape:
                      BoxShape.circle,
                ),

                child: Text(
                  data.day.toString(),

                  style: TextStyle(
                    color: selecionado
                        ? Colors.white
                        : const Color(
                            0xFF333333,
                          ),

                    fontSize: 12,

                    fontWeight:
                        selecionado
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              // ESPAÇO RESERVADO PARA
              // MOSTRAR EVENTOS FUTURAMENTE
              Expanded(
                child: Container(),
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
        color:
            const Color(0xFFFAFAFA),

        border: Border.all(
          color:
              const Color(0xFFEEEEEE),
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
      margin:
          const EdgeInsets.only(
        right: 5,
      ),

      padding:
          const EdgeInsets.symmetric(
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
          fontWeight:
              FontWeight.w500,
        ),
      ),
    );
  }
}