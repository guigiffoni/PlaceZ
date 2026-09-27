import 'package:flutter/material.dart';

class Cadastrador extends StatelessWidget {
  const Cadastrador({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10.0,
            children: [
              Text("Email", textScaler: TextScaler.linear(1.5)),
              TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ),
              Text("Senha", textScaler: TextScaler.linear(1.5)),
              TextField(
                obscureText: true,
                obscuringCharacter: "#",
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ),
              Center(
                child: ElevatedButton(
                  onPressed: () => {},
                  child: Text("Registrar", textScaler: .linear(2.0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
