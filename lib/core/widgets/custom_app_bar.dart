import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
   final String title;
  final VoidCallback? icon;        // زر واحد اختياري
  final VoidCallback? onIconPressed;
  final Widget? leading;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.icon,
    this.onIconPressed,
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: Colors.blue,
      foregroundColor: cs.onSurface,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      leading: leading ??
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onIconPressed,
          ),
      actions: [
        if (actions != null) ...actions!,
        if (icon != null)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: icon,
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}