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
    return AppBar(
      backgroundColor: Colors.blue,
      title: Center(
        child: Text(title, style: TextStyle(color: Colors.white)),
      ),
      leading: leading ??
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onIconPressed,
          ),
      actions: [
        if (actions != null) ...actions!,
        if (icon != null)
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: icon,
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}