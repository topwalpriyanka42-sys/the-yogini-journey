import 'package:material_ui/material_ui.dart';

ThemeData yoginiTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xff667d5d),
        brightness: brightness,
      ).copyWith(
        surface: dark ? const Color(0xff20251f) : const Color(0xfffbf8ef),
        primary: dark ? const Color(0xffbbd2af) : const Color(0xff415b40),
        secondaryContainer: dark
            ? const Color(0xff42412e)
            : const Color(0xfff1e6c9),
      );

  return ThemeData(
    colorScheme: colors,
    useMaterial3: true,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surfaceContainer,
      height: 70,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
  );
}
