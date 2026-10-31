import 'package:flutter/material.dart';
import '../models/app_settings.dart';

// Kept for existing callers while surfaces migrate to Theme.of(context).
const ink = Color(0xff17334b);
const blue = Color(0xff187ba9);
const pale = Color(0xfff4f8fb);

/// Green stays reserved for measurement success in every appearance.
// Palette sources and persistence mappings are documented in docs/theme-palettes.md.
// Neutral light/dark are app palettes; the others adapt published color sets.
ThemeData microTheme([AppearanceTheme appearance = AppearanceTheme.light]) {
  final (
    dark,
    primary,
    secondary,
    background,
    surface,
    text,
    muted,
  ) = switch (appearance) {
    AppearanceTheme.light => (
      false,
      const Color(0xff0969da),
      const Color(0xff8250df),
      const Color(0xfff6f8fa),
      const Color(0xffffffff),
      const Color(0xff1f2328),
      const Color(0xff59636e),
    ),
    AppearanceTheme.dark => (
      true,
      const Color(0xffffffff),
      const Color(0xffe8e8e8),
      const Color(0xff000000),
      const Color(0xff0a0a0a),
      const Color(0xffffffff),
      const Color(0xffc8c8c8),
    ),
    AppearanceTheme.midnight => (
      true,
      const Color(0xff7aa2f7),
      const Color(0xffbb9af7),
      const Color(0xff1a1b26),
      const Color(0xff24283b),
      const Color(0xffc0caf5),
      const Color(0xffa9b1d6),
    ),
    AppearanceTheme.atelier => (
      false,
      const Color(0xff268bd2),
      const Color(0xffb58900),
      const Color(0xffeee8d5),
      const Color(0xfffdf6e3),
      const Color(0xff073642),
      const Color(0xff586e75),
    ),
    AppearanceTheme.lagoon => (
      true,
      const Color(0xff88c0d0),
      const Color(0xffb48ead),
      const Color(0xff2e3440),
      const Color(0xff3b4252),
      const Color(0xffeceff4),
      const Color(0xffd8dee9),
    ),
    AppearanceTheme.porcelain => (
      false,
      const Color(0xff1e66f5),
      const Color(0xff8839ef),
      const Color(0xffe6e9ef),
      const Color(0xffeff1f5),
      const Color(0xff4c4f69),
      const Color(0xff5c5f77),
    ),
    AppearanceTheme.amethyst => (
      true,
      const Color(0xffbd93f9),
      const Color(0xffff79c6),
      const Color(0xff282a36),
      const Color(0xff44475a),
      const Color(0xfff8f8f2),
      const Color(0xfff8f8f2),
    ),
    AppearanceTheme.sunstone => (
      false,
      const Color(0xffaf3a03),
      const Color(0xffb57614),
      const Color(0xffebdbb2),
      const Color(0xfffbf1c7),
      const Color(0xff3c3836),
      const Color(0xff665c54),
    ),
    AppearanceTheme.arctic => (
      false,
      const Color(0xff4c566a),
      const Color(0xff5e81ac),
      const Color(0xffe5e9f0),
      const Color(0xffeceff4),
      const Color(0xff2e3440),
      const Color(0xff4c566a),
    ),
  };
  // Choose legible button text from the actual accent, not the theme brightness.
  final onAccent = primary.computeLuminance() > .179
      ? Colors.black
      : Colors.white;
  final onSecondary = secondary.computeLuminance() > .179
      ? Colors.black
      : Colors.white;
  Color tint(Color color, double opacity) =>
      Color.alphaBlend(color.withValues(alpha: opacity), surface);
  final colors = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onAccent,
    primaryContainer: tint(primary, dark ? .16 : .15),
    onPrimaryContainer: text,
    primaryFixed: tint(primary, .12),
    primaryFixedDim: tint(primary, .22),
    onPrimaryFixed: text,
    onPrimaryFixedVariant: primary,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: tint(secondary, .12),
    onSecondaryContainer: text,
    secondaryFixed: tint(secondary, .12),
    secondaryFixedDim: tint(secondary, .22),
    onSecondaryFixed: text,
    onSecondaryFixedVariant: secondary,
    tertiary: secondary,
    onTertiary: onSecondary,
    tertiaryContainer: tint(secondary, .12),
    onTertiaryContainer: text,
    tertiaryFixed: tint(secondary, .12),
    tertiaryFixedDim: tint(secondary, .22),
    onTertiaryFixed: text,
    onTertiaryFixedVariant: secondary,
    error: dark ? const Color(0xffffb4ab) : const Color(0xffab3734),
    onError: dark ? const Color(0xff601410) : Colors.white,
    errorContainer: const Color(0xffffdad6),
    onErrorContainer: const Color(0xff410002),
    surface: surface,
    onSurface: text,
    surfaceDim: tint(text, .12),
    surfaceBright: surface,
    surfaceContainerLowest: surface,
    surfaceContainerLow: background,
    surfaceContainer: tint(text, .04),
    surfaceContainerHigh: tint(text, .07),
    surfaceContainerHighest: tint(text, .10),
    onSurfaceVariant: muted,
    outline: tint(muted, .75),
    outlineVariant: tint(muted, .22),
    inverseSurface: text,
    onInverseSurface: surface,
    inversePrimary: tint(primary, .25),
    surfaceTint: primary,
    shadow: Colors.black,
    scrim: Colors.black,
  );
  final textTheme = TextTheme(
    headlineMedium: TextStyle(
      fontSize: 30,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: text,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: text,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: text,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: text,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: text),
    bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: text),
    bodySmall: TextStyle(fontSize: 13, height: 1.45, color: muted),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: text,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: muted,
    ),
  ).apply(fontFamily: 'Roboto');
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: colors.outlineVariant),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: colors.outline),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: colors,
    scaffoldBackgroundColor: background,
    canvasColor: surface,
    textTheme: textTheme,
    iconTheme: IconThemeData(color: muted, size: 22),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    dividerColor: colors.outlineVariant,
    dividerTheme: DividerThemeData(color: colors.outlineVariant, thickness: 1),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: surface,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
      floatingLabelStyle: textTheme.labelLarge?.copyWith(color: primary),
      hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
      helperStyle: textTheme.bodySmall,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
      disabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: textTheme.labelLarge,
        elevation: 0,
        shape: controlShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: textTheme.labelLarge,
        shape: controlShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle: textTheme.labelLarge,
        shape: controlShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return colors.outlineVariant;
        return states.contains(WidgetState.selected) ? colors.onPrimary : muted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.surfaceContainerHighest;
        }
        return states.contains(WidgetState.selected)
            ? primary
            : colors.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return colors.outlineVariant;
        return states.contains(WidgetState.selected)
            ? Colors.transparent
            : colors.outline;
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: colors.primaryContainer,
      disabledColor: colors.surfaceContainerHighest,
      labelStyle: textTheme.labelLarge,
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: primary),
      checkmarkColor: primary,
      side: BorderSide(color: colors.outlineVariant),
      shape: controlShape,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      elevation: 0,
      pressElevation: 0,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: colors.primaryContainer,
      thumbColor: primary,
      overlayColor: primary.withValues(alpha: .10),
      trackHeight: 4,
      valueIndicatorColor: primary,
      valueIndicatorTextStyle: textTheme.labelLarge?.copyWith(
        color: colors.onPrimary,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: text,
      titleTextStyle: textTheme.bodyLarge,
      subtitleTextStyle: textTheme.bodySmall,
      selectedColor: primary,
      selectedTileColor: colors.primaryContainer,
      minVerticalPadding: 12,
      shape: controlShape,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      backgroundColor: surface,
      collapsedBackgroundColor: surface,
      textColor: text,
      collapsedTextColor: text,
      iconColor: primary,
      collapsedIconColor: muted,
      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      shape: cardShape,
      collapsedShape: cardShape,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: colors.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected) ? primary : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : muted,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: cardShape,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: text,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: surface),
      actionTextColor: colors.inversePrimary,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: controlShape,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: primary.withValues(alpha: .18),
      selectionHandleColor: primary,
    ),
  );
}
