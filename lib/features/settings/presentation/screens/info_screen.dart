import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InfoSection {
  final IconData icon;
  final String title;
  final String content;

  InfoSection({required this.icon, required this.title, required this.content});
}

class InfoScreen extends StatelessWidget {
  final String title;
  final IconData headerIcon;
  final Color headerColor;
  final String topDescription;
  final List<InfoSection> sections;
  final Widget? customBottomWidget;

  const InfoScreen({
    super.key,
    required this.title,
    required this.headerIcon,
    required this.headerColor,
    required this.topDescription,
    required this.sections,
    this.customBottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [headerColor.withOpacity(0.2), headerColor.withOpacity(0.02)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 30),
                      Icon(headerIcon, size: 70, color: headerColor)
                          .animate()
                          .scale(duration: 500.ms, curve: Curves.easeOutBack)
                          .fadeIn(),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ).animate().slideY(begin: 0.5, end: 0, duration: 400.ms).fadeIn(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topDescription,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 30),
                  ...sections.asMap().entries.map((entry) {
                    final index = entry.key;
                    final section = entry.value;
                    return _buildSectionCard(context, section, isDark, index)
                        .animate()
                        .fadeIn(delay: (300 + (index * 150)).ms)
                        .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut);
                  }).toList(),
                  if (customBottomWidget != null) ...[
                    const SizedBox(height: 20),
                    customBottomWidget!.animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),
                  ],
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, InfoSection section, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: headerColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(section.icon, color: headerColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            section.content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
