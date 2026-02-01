import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? icon;
  final VoidCallback? onIconPressed;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showElevation;
  final bool showShadow;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? titleWidget;
  final bool centerTitle;

  const CustomAppBar({
    super.key,
    required this.title,
    this.icon,
    this.onIconPressed,
    this.leading,
    this.actions,
    this.showElevation = true,
    this.showShadow = true,
    this.backgroundColor,
    this.foregroundColor,
    this.titleWidget,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final bgColor = backgroundColor ?? colorScheme.primary;
    final fgColor = foregroundColor ?? colorScheme.onPrimary;
    
    return Container(
      decoration: showShadow
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      child: AppBar(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: showElevation ? 4 : 0,
        centerTitle: centerTitle,
        title: Center(
          child: titleWidget ??
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
        ),
        leading: leading ??
            (Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(Icons.arrow_back, color: fgColor),
                    onPressed: onIconPressed ?? () => Navigator.maybePop(context),
                  )
                : null),
        actions: [
          if (actions != null) ...actions!,
          if (icon != null)
            IconButton(
              icon: Icon(Icons.search, color: fgColor),
              onPressed: icon,
            ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}