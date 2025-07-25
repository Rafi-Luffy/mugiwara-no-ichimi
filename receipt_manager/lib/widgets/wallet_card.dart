import 'package:flutter/material.dart';

class WalletCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const WalletCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, child: Text(title[0])),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}