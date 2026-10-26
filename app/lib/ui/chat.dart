import 'package:flutter/material.dart';

class TelaChat extends StatefulWidget {
  const TelaChat({super.key});

  @override
  State<TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<TelaChat> {
  final TextEditingController mensagemController =
      TextEditingController();

  final List<String> mensagens = [
    "Massa demais!",
    "Bora fazer alguma coisa",
    "Pizza?",
  ];

  void enviarMensagem() {
    String mensagem = mensagemController.text.trim();

    if (mensagem.isNotEmpty) {
      setState(() {
        mensagens.add(mensagem);
      });

      mensagemController.clear();
    }
  }

  @override
  void dispose() {
    mensagemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE0E0E0),
              ),
            ),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                child: Icon(Icons.person),
              ),

              SizedBox(width: 12),

              Expanded(
                child: Text(
                  "Fulano da Silva",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Icon(Icons.phone_outlined),

              SizedBox(width: 20),

              Icon(Icons.more_vert),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mensagens.length,
            itemBuilder: (context, index) {
              bool minhaMensagem = index >= 3;

              return Align(
                alignment: minhaMensagem
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 300,
                  ),
                  margin: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: minhaMensagem
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: Text(
                    mensagens[index],
                    style: TextStyle(
                      color: minhaMensagem
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: mensagemController,
                  onSubmitted: (_) {
                    enviarMensagem();
                  },
                  decoration: InputDecoration(
                    hintText: "Mensagem",
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                onPressed: enviarMensagem,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}