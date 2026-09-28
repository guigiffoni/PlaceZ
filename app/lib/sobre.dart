import 'package:flutter/material.dart';

class TelaSobre extends StatelessWidget {
  const TelaSobre({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "Sobre o App",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Aplicativo desenvolvido por:",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 12),

            Text(
              "Guilherme Amaral Giffoni\n"
              "Pedro Henrique Ferreira\n"
              "Rodrigo Fernandes Moraes",
              style: TextStyle(
                fontSize: 15,
                height: 1.7,
              ),
            ),

            SizedBox(height: 35),

            Text(
              "Sobre o PlaceZ",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 12),

            Text(
              "Criado no segundo semestre de 2026 para a disciplina "
              "de Desenvolvimento Móvel, com o intuito de facilitar "
              "o encontro entre amigos.",
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),

            SizedBox(height: 25),

            Text(
              "O PlaceZ auxilia grupos na organização de encontros "
              "e eventos, permitindo consultar lugares, organizar "
              "datas e facilitar a comunicação entre os participantes.",
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),

            Spacer(),

            Center(
              child: Text(
                "MIT License",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}