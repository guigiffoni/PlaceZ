import 'package:flutter/material.dart';
import '../data/models/pessoa.dart';
import '../data/dao/pessoa_dao.dart';

class TelaContatos extends StatefulWidget {
  const TelaContatos({super.key});

  @override
  State<TelaContatos> createState() => _TelaContatosState();
}

class _TelaContatosState extends State<TelaContatos> {
  final PessoaDao _pessoaDao = PessoaDao();
  final TextEditingController _textController = TextEditingController();
  
  List<Pessoa> _contatos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarContatos();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // Busca os contatos do banco
  Future<void> _carregarContatos() async {
    final contatosDoBanco = await _pessoaDao.getAll();
    
    if (mounted) {
      setState(() {
        _contatos = contatosDoBanco;
        _isLoading = false;
      });
    }
  }

  // Adiciona um novo contato no banco
  Future<void> _adicionarContato() async {
    final nome = _textController.text.trim();
    if (nome.isNotEmpty) {
      // Cria e insere a nova pessoa
      await _pessoaDao.insert(Pessoa(nome: nome)); 
      _textController.clear();
      _carregarContatos(); // Recarrega a lista para exibir o novo item
    }
  }

  // Deleta o contato do banco
  Future<void> _deletarContato(Pessoa pessoa) async {
    await _pessoaDao.delete(pessoa.id!);
    _carregarContatos(); // Recarrega a lista após deletar
  }

  // Diálogo simples de confirmação
  void _confirmarDelecao(Pessoa pessoa) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir Contato'),
          content: Text('Excluir "${pessoa.nome}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Não'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Fecha o diálogo
                _deletarContato(pessoa); // Executa a exclusão no banco
              },
              child: const Text('Sim'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contatos')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _contatos.isEmpty
                    ? const Center(child: Text('Nenhum contato.'))
                    : ListView.builder(
                        itemCount: _contatos.length,
                        itemBuilder: (context, index) {
                          final pessoa = _contatos[index];
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(pessoa.nome),
                            onLongPress: () => _confirmarDelecao(pessoa),
                          );
                        },
                      ),
          ),
          
          // Área de input
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Nome',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _adicionarContato(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _adicionarContato,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}