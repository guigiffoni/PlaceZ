import 'package:flutter/material.dart';

class TelaEvento extends StatefulWidget {
  const TelaEvento({super.key});

  @override
  State<TelaEvento> createState() => _TelaEventoState();
}

class _TelaEventoState extends State<TelaEvento> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController localController = TextEditingController();

  DateTime? dataSelecionada;
  TimeOfDay? horarioSelecionado;

  @override
  void dispose() {
    nomeController.dispose();
    localController.dispose();
    super.dispose();
  }

  Future<void> escolherData() async {
    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (data != null) {
      setState(() {
        dataSelecionada = data;
      });
    }
  }

  Future<void> escolherHorario() async {
    final TimeOfDay? horario = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (horario != null) {
      setState(() {
        horarioSelecionado = horario;
      });
    }
  }

  void criarEvento() {
    if (nomeController.text.trim().isEmpty ||
        localController.text.trim().isEmpty ||
        dataSelecionada == null ||
        horarioSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preencha todas as informações do evento."),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Evento criado com sucesso!"),
      ),
    );

    nomeController.clear();
    localController.clear();

    setState(() {
      dataSelecionada = null;
      horarioSelecionado = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Adicionar evento",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          const Text("Nome do evento"),

          const SizedBox(height: 7),

          TextField(
            controller: nomeController,
            decoration: InputDecoration(
              hintText: "Ex: Pizza com os amigos",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text("Local"),

          const SizedBox(height: 7),

          TextField(
            controller: localController,
            decoration: InputDecoration(
              hintText: "Ex: Pizzaria Bella Napoli",
              prefixIcon: const Icon(
                Icons.location_on_outlined,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: escolherData,
              icon: const Icon(
                Icons.calendar_month,
              ),
              label: Text(
                dataSelecionada == null
                    ? "Escolher data"
                    : "${dataSelecionada!.day.toString().padLeft(2, '0')}/"
                        "${dataSelecionada!.month.toString().padLeft(2, '0')}/"
                        "${dataSelecionada!.year}",
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: escolherHorario,
              icon: const Icon(
                Icons.access_time,
              ),
              label: Text(
                horarioSelecionado == null
                    ? "Escolher horário"
                    : horarioSelecionado!.format(context),
              ),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: criarEvento,
              icon: const Icon(Icons.add),
              label: const Text(
                "Criar evento",
              ),
            ),
          ),
        ],
      ),
    );
  }
}