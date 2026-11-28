import 'package:flutter/material.dart';

/// Tokens de layout usados pela identidade visual do PlaceZ.
class PlacezTokens {
  const PlacezTokens._();

  static const double espXs = 4;
  static const double espSm = 8;
  static const double espMd = 12;
  static const double espLg = 16;
  static const double espXl = 24;
  static const double espXxl = 32;

  static const double raioSm = 10;
  static const double raioMd = 14;
  static const double raioLg = 20;
  static const double raioXl = 28;

  static const BorderRadius bordaSm = BorderRadius.all(Radius.circular(raioSm));
  static const BorderRadius bordaMd = BorderRadius.all(Radius.circular(raioMd));
  static const BorderRadius bordaLg = BorderRadius.all(Radius.circular(raioLg));
}

/// Cores fixas da identidade do PlaceZ, usadas como acentos sobre a cor
/// principal escolhida pelo usuário.
class PlacezCores {
  const PlacezCores._();

  static const Color teal = Color(0xFF0F9D8A);
  static const Color ambar = Color(0xFFD97706);
  static const Color roxo = Color(0xFF7C3AED);
  static const Color rosa = Color(0xFFDB2777);
  static const Color azul = Color(0xFF2563EB);
}

/// Par de cores (fundo/frente/borda) para transmitir um estado.
class PaletaStatus {
  final Color fundo;
  final Color frente;
  final Color borda;

  const PaletaStatus({
    required this.fundo,
    required this.frente,
    required this.borda,
  });
}

extension CoresSemanticas on ColorScheme {
  bool get ehEscuro => brightness == Brightness.dark;

  /// Cor sutil para bordas e divisores, evitando linhas duras.
  Color get bordaSutil =>
      outlineVariant.withValues(alpha: ehEscuro ? 0.7 : 0.6);

  /// Superfície de cartões e blocos.
  Color get superficieCartao => surfaceContainerLow;

  PaletaStatus _acento(Color cor) {
    final frente = ehEscuro
        ? Color.lerp(cor, Colors.white, 0.38)!
        : Color.lerp(cor, Colors.black, 0.12)!;
    final fundo = cor.withValues(alpha: ehEscuro ? 0.24 : 0.13);
    final borda = cor.withValues(alpha: ehEscuro ? 0.48 : 0.3);
    return PaletaStatus(fundo: fundo, frente: frente, borda: borda);
  }

  PaletaStatus get acentoTeal => _acento(PlacezCores.teal);
  PaletaStatus get acentoAmbar => _acento(PlacezCores.ambar);
  PaletaStatus get acentoRoxo => _acento(PlacezCores.roxo);
  PaletaStatus get acentoRosa => _acento(PlacezCores.rosa);
  PaletaStatus get acentoAzul => _acento(PlacezCores.azul);

  /// Faixa multicolorida da marca.
  LinearGradient get gradienteMarca => LinearGradient(
    colors: [primary, acentoTeal.frente, acentoAmbar.frente],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Paleta estável para o avatar de iniciais de uma pessoa.
  PaletaStatus paletaAvatar(String nome, int usuarioId) {
    final paletas = [
      acentoTeal,
      acentoAmbar,
      acentoRoxo,
      acentoRosa,
      acentoAzul,
    ];
    final soma = nome.codeUnits.fold<int>(
      usuarioId.abs(),
      (total, codigo) => total + codigo,
    );
    return paletas[soma % paletas.length];
  }

  PaletaStatus get sucesso => ehEscuro
      ? const PaletaStatus(
          fundo: Color(0xFF17351F),
          frente: Color(0xFFA7E8B5),
          borda: Color(0xFF2E5E3A),
        )
      : const PaletaStatus(
          fundo: Color(0xFFE3F5E6),
          frente: Color(0xFF1B5E20),
          borda: Color(0xFFAAD5B0),
        );

  PaletaStatus get alerta => ehEscuro
      ? const PaletaStatus(
          fundo: Color(0xFF3A2E12),
          frente: Color(0xFFF5D98B),
          borda: Color(0xFF5C4A1E),
        )
      : const PaletaStatus(
          fundo: Color(0xFFFFF3D6),
          frente: Color(0xFF6D4C00),
          borda: Color(0xFFE8CF8F),
        );

  PaletaStatus get rascunho => PaletaStatus(
    fundo: tertiaryContainer,
    frente: onTertiaryContainer,
    borda: tertiary.withValues(alpha: 0.35),
  );

  PaletaStatus get cancelado => PaletaStatus(
    fundo: errorContainer,
    frente: onErrorContainer,
    borda: error.withValues(alpha: 0.35),
  );
}

/// Constrói o tema claro/escuro do PlaceZ a partir da cor escolhida.
ThemeData construirTema({required Color seed, required Brightness brightness}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );

  final texto = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.35),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.35),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );

  final bordaCampo = OutlineInputBorder(
    borderRadius: PlacezTokens.bordaMd,
    borderSide: BorderSide(color: scheme.bordaSutil),
  );

  return base.copyWith(
    textTheme: texto,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      toolbarHeight: 56,
      titleTextStyle: texto.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      shape: Border(bottom: BorderSide(color: scheme.bordaSutil)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.superficieCartao,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: PlacezTokens.bordaLg,
        side: BorderSide(color: scheme.bordaSutil),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      minVerticalPadding: 10,
      titleTextStyle: texto.bodyLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: texto.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primaryContainer,
      secondarySelectedColor: scheme.secondaryContainer,
      disabledColor: scheme.surfaceContainerHighest,
      labelStyle: texto.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      secondaryLabelStyle: texto.labelMedium,
      side: BorderSide(color: scheme.bordaSutil),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        shape: const RoundedRectangleBorder(borderRadius: PlacezTokens.bordaMd),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(borderRadius: PlacezTokens.bordaMd),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(borderRadius: PlacezTokens.bordaSm),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: texto.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: texto.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      border: bordaCampo,
      enabledBorder: bordaCampo,
      disabledBorder: bordaCampo,
      focusedBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      elevation: 0,
      height: 72,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((estados) {
        final selecionado = estados.contains(WidgetState.selected);
        return texto.labelSmall?.copyWith(
          color: selecionado ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((estados) {
        final selecionado = estados.contains(WidgetState.selected);
        return IconThemeData(
          color: selecionado
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
          size: 24,
        );
      }),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      unselectedLabelStyle: texto.labelLarge,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: PlacezTokens.bordaLg),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: texto.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: const RoundedRectangleBorder(borderRadius: PlacezTokens.bordaMd),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.bordaSutil,
      thickness: 1,
      space: 1,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        side: BorderSide(color: scheme.bordaSutil),
        shape: const RoundedRectangleBorder(borderRadius: PlacezTokens.bordaMd),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: PlacezTokens.bordaMd),
      textStyle: texto.bodyMedium,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: PlacezTokens.bordaSm,
      ),
      textStyle: texto.bodySmall?.copyWith(color: scheme.onInverseSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PlacezTokens.raioXl),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: PlacezTokens.bordaLg),
    ),
  );
}
