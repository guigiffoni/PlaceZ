import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/friends/friends_repository.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/amizade.dart';

class TelaScannerQr extends StatefulWidget {
  final AuthController authController;

  const TelaScannerQr({super.key, required this.authController});

  @override
  State<TelaScannerQr> createState() => _TelaScannerQrState();
}

class _TelaScannerQrState extends State<TelaScannerQr> {
  late final MobileScannerController _scanner;
  late final FriendsRepository _repositorio;
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    final auth = widget.authController;
    _scanner = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _repositorio = FriendsRepository(
      tokenProvider: () async => auth.sessao?.token,
      onUnauthorized: auth.tratarNaoAutorizado,
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  String? _usernameDoPayload(String? bruto) {
    var texto = (bruto ?? '').trim();
    if (texto.isEmpty) return null;
    if (texto.toLowerCase().startsWith('placez://usuario/')) {
      texto = texto.substring('placez://usuario/'.length);
    }
    texto = texto.trim().toLowerCase();
    if (texto.startsWith('@')) texto = texto.substring(1);
    final match = RegExp(r'^[a-z0-9._-]{3,40}$').firstMatch(texto);
    return match?.group(0);
  }

  void _onDetect(BarcodeCapture captura) {
    if (_processando || captura.barcodes.isEmpty) return;
    final valor = captura.barcodes.first.rawValue;
    _processar(valor);
  }

  Future<void> _processar(String? valor) async {
    final username = _usernameDoPayload(valor);
    if (username == null) {
      _avisar('QR Code inválido. Ele deve conter um username do PlaceZ.');
      return;
    }

    setState(() => _processando = true);
    try {
      await _scanner.stop();
    } catch (_) {
      // A câmera pode não estar iniciada no fluxo de imagem da galeria.
    }

    try {
      final resultado = await _repositorio.buscar(username);
      ResultadoBuscaUsuario? usuario;
      for (final item in resultado.usuarios) {
        if (item.usuario.username == username) {
          usuario = item;
          break;
        }
      }

      if (!mounted) return;
      if (usuario == null) {
        _avisar('Usuário @$username não encontrado.');
        await _retomar();
        return;
      }

      final acao = await _mostrarResultado(usuario);
      if (!mounted) return;
      if (!acao) {
        await _retomar();
        return;
      }

      await _executarAcao(usuario);
    } on ApiException catch (erro) {
      if (mounted) _avisar(erro.message);
      await _retomar();
    } catch (erro) {
      if (mounted) _avisar('Não foi possível ler o QR Code: $erro');
      await _retomar();
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<bool> _mostrarResultado(ResultadoBuscaUsuario resultado) async {
    final usuario = resultado.usuario;
    final tema = Theme.of(context);
    String? rotuloAcao;
    String mensagem;

    switch (resultado.relacao) {
      case RelacaoUsuario.nenhuma:
        rotuloAcao = 'Adicionar';
        mensagem = 'Enviar solicitação de amizade para ${usuario.nome}?';
        break;
      case RelacaoUsuario.solicitacaoRecebida:
        rotuloAcao = 'Aceitar';
        mensagem = '${usuario.nome} já enviou uma solicitação para você.';
        break;
      case RelacaoUsuario.solicitacaoEnviada:
        mensagem = 'Você já enviou uma solicitação para ${usuario.nome}.';
        break;
      case RelacaoUsuario.amigos:
        mensagem = 'Você e ${usuario.nome} já são amigos.';
        break;
    }

    final acao = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('QR Code reconhecido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Text(usuario.iniciais)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(usuario.nome),
                        Text(
                          usuario.identificador,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(mensagem),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar'),
            ),
            if (rotuloAcao != null)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(rotuloAcao),
              ),
          ],
        );
      },
    );
    return acao == true;
  }

  Future<void> _executarAcao(ResultadoBuscaUsuario resultado) async {
    try {
      if (resultado.relacao == RelacaoUsuario.nenhuma) {
        await _repositorio.enviarSolicitacao(resultado.usuario.username);
      } else if (resultado.relacao == RelacaoUsuario.solicitacaoRecebida &&
          resultado.solicitacaoId != null) {
        await _repositorio.aceitar(resultado.solicitacaoId!);
      }
    } on ApiException catch (erro) {
      if (!mounted) return;
      _avisar(erro.message);
      await _retomar();
      return;
    } catch (erro) {
      if (!mounted) return;
      _avisar('Não foi possível concluir a ação: $erro');
      await _retomar();
      return;
    }

    if (!mounted) return;
    _avisar(
      resultado.relacao == RelacaoUsuario.solicitacaoRecebida
          ? 'Solicitação aceita.'
          : 'Solicitação enviada.',
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _retomar() async {
    if (!mounted) return;
    setState(() => _processando = false);
    try {
      await _scanner.start();
    } catch (_) {
      // A câmera pode continuar indisponível; o usuário pode usar a galeria.
    }
  }

  Future<void> _escolherImagem() async {
    try {
      final arquivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (arquivo == null || !mounted) return;
      final captura = await _scanner.analyzeImage(arquivo.path);
      if (captura == null || captura.barcodes.isEmpty) {
        _avisar('Nenhum QR Code encontrado na imagem.');
        return;
      }
      await _processar(captura.barcodes.first.rawValue);
    } catch (erro) {
      if (mounted) _avisar('Não foi possível ler a imagem: $erro');
    }
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        actions: [
          IconButton(
            tooltip: 'Escolher imagem da galeria',
            onPressed: _processando ? null : _escolherImagem,
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Não foi possível abrir a câmera. Use a galeria para '
                      'escolher uma imagem com QR Code.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _processando
                    ? 'Processando QR Code...'
                    : 'Aponte a câmera para o QR Code de um amigo.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
