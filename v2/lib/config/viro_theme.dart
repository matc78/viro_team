import 'package:flutter/material.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/config/viro_motion.dart';
import 'package:viro_team_v2/config/viro_typography.dart';

export 'package:viro_team_v2/config/viro_colors.dart';
export 'package:viro_team_v2/config/viro_motion.dart';
export 'package:viro_team_v2/config/viro_spacing.dart';
export 'package:viro_team_v2/config/viro_typography.dart';
export 'package:viro_team_v2/config/viro_icons.dart';

/// Thème Material 3 — design system ViroTeam v2 (mode clair uniquement).
abstract final class ViroTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: ViroColors.primary600,
      onPrimary: ViroColors.white,
      primaryContainer: ViroColors.primary50,
      onPrimaryContainer: ViroColors.primary800,
      secondary: ViroColors.primary800,
      onSecondary: ViroColors.white,
      surface: ViroColors.white,
      onSurface: ViroColors.gray900,
      error: ViroColors.error,
      onError: ViroColors.white,
      outline: ViroColors.gray300,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ViroColors.scaffoldHighlight,
      dividerColor: ViroColors.gray200,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: ViroColors.primary100.withValues(alpha: 0.35),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );

    final textTheme = ViroTypography.textTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: ViroSpacing.topBarHeight,
        backgroundColor: Colors.transparent,
        foregroundColor: ViroColors.primary800,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: ViroColors.primary800),
        iconTheme: const IconThemeData(color: ViroColors.primary600),
        shadowColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: ViroColors.surfaceCard,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: ViroSpacing.md),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.cardRadius),
        ),
        shadowColor: ViroColors.primary800.withValues(alpha: 0.12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButtonStyle(textTheme),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _secondaryButtonStyle(textTheme),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _tertiaryButtonStyle(textTheme),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ViroColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ViroSpacing.md,
          vertical: 12,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: ViroColors.gray400,
        ),
        labelStyle: textTheme.labelLarge,
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: ViroColors.error),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
          borderSide: const BorderSide(color: ViroColors.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
          borderSide: const BorderSide(color: ViroColors.primary600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
          borderSide: const BorderSide(color: ViroColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
          borderSide: const BorderSide(color: ViroColors.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ViroColors.gray50,
        selectedColor: ViroColors.primary600,
        side: const BorderSide(color: ViroColors.gray200),
        labelStyle: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: ViroColors.primary800,
        ),
        secondaryLabelStyle: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: ViroColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
        ),
        // Durée appliquée via [ViroSnackBar.show] et [ProjectConfig.snackBarDuration].
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ViroColors.primary600,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: ViroMotion.elevationFab,
        highlightElevation: ViroMotion.elevationFab + 4,
        backgroundColor: ViroColors.primary600,
        foregroundColor: ViroColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        sizeConstraints: const BoxConstraints.tightFor(
          width: 56,
          height: 56,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(ViroSpacing.minTouchTarget),
          foregroundColor: ViroColors.primary800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: ViroMotion.elevationMenu,
        color: ViroColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.cardRadius),
          side: const BorderSide(color: ViroColors.gray200),
        ),
        textStyle: textTheme.bodyLarge,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          elevation: WidgetStateProperty.all(ViroMotion.elevationMenu),
          backgroundColor: WidgetStateProperty.all(ViroColors.white),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ViroSpacing.cardRadius),
              side: const BorderSide(color: ViroColors.gray200),
            ),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: ViroMotion.elevationMenu,
        backgroundColor: ViroColors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: ViroColors.gray300,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ViroSpacing.cardRadius + 4),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: ViroMotion.elevationMenu,
        backgroundColor: ViroColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.cardRadius),
        ),
        titleTextStyle: textTheme.headlineMedium,
        contentTextStyle: textTheme.bodyLarge,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: ViroSpacing.sm,
        contentPadding: const EdgeInsets.symmetric(horizontal: ViroSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
        ),
      ),
    );
  }

  static ButtonStyle _primaryButtonStyle(TextTheme textTheme) {
    return ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(ViroSpacing.buttonHeightLarge),
      backgroundColor: ViroColors.primary600,
      foregroundColor: ViroColors.white,
      disabledBackgroundColor: ViroColors.gray200,
      disabledForegroundColor: ViroColors.gray400,
      elevation: ViroMotion.elevationRest,
      shadowColor: ViroColors.primary900.withValues(alpha: 0.2),
      textStyle: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: ViroColors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
      ),
    ).copyWith(
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return 0;
        if (states.contains(WidgetState.pressed)) return ViroMotion.elevationPressed;
        if (states.contains(WidgetState.hovered)) return ViroMotion.elevationHover;
        return ViroMotion.elevationRest;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return ViroColors.primary800.withValues(alpha: 0.2);
        }
        if (states.contains(WidgetState.hovered)) {
          return ViroColors.primary600.withValues(alpha: 0.12);
        }
        return null;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return ViroColors.gray200;
        if (states.contains(WidgetState.pressed)) return ViroColors.primary900;
        if (states.contains(WidgetState.hovered)) return ViroColors.primary800;
        return ViroColors.primary600;
      }),
    );
  }

  static ButtonStyle _secondaryButtonStyle(TextTheme textTheme) {
    return OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(ViroSpacing.buttonHeightMedium),
      foregroundColor: ViroColors.primary600,
      disabledForegroundColor: ViroColors.gray400,
      elevation: ViroMotion.elevationRest,
      shadowColor: ViroColors.primary900.withValues(alpha: 0.1),
      side: const BorderSide(color: ViroColors.primary600, width: 2),
      textStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ViroSpacing.buttonRadius),
      ),
    ).copyWith(
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return 0;
        if (states.contains(WidgetState.pressed)) return ViroMotion.elevationPressed;
        if (states.contains(WidgetState.hovered)) return ViroMotion.elevationHover;
        return ViroMotion.elevationRest;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: ViroColors.gray300, width: 2);
        }
        return const BorderSide(color: ViroColors.primary600, width: 2);
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return ViroColors.primary100;
        if (states.contains(WidgetState.hovered)) return ViroColors.primary50;
        return ViroColors.white;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return ViroColors.gray400;
        if (states.contains(WidgetState.pressed)) return ViroColors.primary900;
        if (states.contains(WidgetState.hovered)) return ViroColors.primary800;
        return ViroColors.primary600;
      }),
    );
  }

  static ButtonStyle _tertiaryButtonStyle(TextTheme textTheme) {
    return TextButton.styleFrom(
      minimumSize: const Size(0, ViroSpacing.buttonHeightSmall),
      foregroundColor: ViroColors.primary600,
      disabledForegroundColor: ViroColors.gray400,
      textStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
