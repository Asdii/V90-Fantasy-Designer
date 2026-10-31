import 'package:flutter/material.dart';
import '../models/app_settings.dart';

// Kept for existing callers while surfaces migrate to Theme.of(context).
const ink = Color(0xff17334b);
const blue = Color(0xff187ba9);
const pale = Color(0xfff4f8fb);

/// Green stays reserved for measurement success in every appearance.
ThemeData microTheme([AppearanceTheme appearance = AppearanceTheme.atelier]) {
  final (
    primary,
    secondary,
    background,
    surface,
    text,
    muted,
  ) = switch (appearance) {
    AppearanceTheme.atelier => (
      const Color(0xff174f79),
      const Color(0xffa25e32),
      const Color(0xfff1e9da),
      const Color(0xfffffdf8),
      const Color(0xff263742),
      const Color(0xff59656c),
    ),
    AppearanceTheme.lagoon => (
      const Color(0xff006c9c),
      const Color(0xff2363aa),
      const Color(0xffdfedf7),
      const Color(0xfffbfdff),
      const Color(0xff193747),
      const Color(0xff516674),
    ),
    AppearanceTheme.porcelain => (
      const Color(0xff344f76),
      const Color(0xff9c5976),
      const Color(0xffe9edf3),
      const Color(0xffffffff),
      const Color(0xff29313d),
      const Color(0xff606773),
    ),
    AppearanceTheme.amethyst => (
      const Color(0xff683da0),
      const Color(0xff9d507d),
      const Color(0xffeee2f9),
      const Color(0xfffffbff),
      const Color(0xff382d46),
      const Color(0xff6e6178),
    ),
    AppearanceTheme.sunstone => (
      const Color(0xff965c18),
      const Color(0xff486d95),
      const Color(0xfff7e8cd),
      const Color(0xfffffaf0),
      const Color(0xff453522),
      const Color(0xff72604b),
    ),
    AppearanceTheme.arctic => (
      const Color(0xff1455ba),
      const Color(0xff744dab),
      const Color(0xffe1e9fc),
      const Color(0xfff8faff),
      const Color(0xff1c3157),
      const Color(0xff526682),
    ),
    AppearanceTheme.midnight => (
      const Color(0xff7dbfff),
      const Color(0xffbc9bea),
      const Color(0xff101c30),
      const Color(0xff1b2c45),
      const Color(0xffe8f1ff),
      const Color(0xffb2c3dc),
    ),
  };
  final dark = appearance == AppearanceTheme.midnight;
  final onAccent = dark ? const Color(0xff0e223b) : Colors.white;
  Color tint(Color color, double opacity) =>
      Color.alphaBlend(color.withValues(alpha: opacity), surface);
  final colors = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onAccent,
    primaryContainer: tint(primary, dark ? .16 : .15),
    onPrimaryContainer: primary,
    primaryFixed: tint(primary, .12),
    primaryFixedDim: tint(primary, .22),
    onPrimaryFixed: text,
    onPrimaryFixedVariant: primary,
    secondary: secondary,
    onSecondary: onAccent,
    secondaryContainer: tint(secondary, .12),
    onSecondaryContainer: secondary,
    secondaryFixed: tint(secondary, .12),
    secondaryFixedDim: tint(secondary, .22),
    onSecondaryFixed: text,
    onSecondaryFixedVariant: secondary,
    tertiary: secondary,
    onTertiary: onAccent,
    tertiaryContainer: tint(secondary, .12),
    onTertiaryContainer: secondary,
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
