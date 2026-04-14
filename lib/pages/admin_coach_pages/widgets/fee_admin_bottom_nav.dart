import 'package:flutter/material.dart';

import '../../../theme/viro_theme.dart';
import '../admin_shell.dart';

class FeeAdminBottomNav extends StatelessWidget {
  final int currentIndex;

  const FeeAdminBottomNav({super.key, this.currentIndex = 2});

  static const _tabs = [
    ('Équipement', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    ('Communiquer', Icons.campaign_outlined, Icons.campaign_rounded),
    ('Accueil', Icons.home_outlined, Icons.home_rounded),
    ('Coach', Icons.sports_score_outlined, Icons.sports_score),
    (
      'Planning',
      Icons.calendar_month_outlined,
      Icons.calendar_month_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (int i = 0; i < _tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminShell(initialIndex: i),
                        ),
                        (route) => false,
                      );
                    },
                    child: _FeeAdminBottomNavItem(
                      label: _tabs[i].$1,
                      icon: _tabs[i].$2,
                      selectedIcon: _tabs[i].$3,
                      selected: i == currentIndex,
                      center: i == 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeeAdminBottomNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final bool center;

  const _FeeAdminBottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    if (center) {
      return Center(
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? ViroColors.primary : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            selected ? selectedIcon : icon,
            size: 24,
            color: selected ? Colors.white : Colors.grey[500],
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          selected ? selectedIcon : icon,
          size: selected ? 26 : 22,
          color: selected ? ViroColors.primary : Colors.grey[400],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: Colors.grey[400]),
        ),
      ],
    );
  }
}
