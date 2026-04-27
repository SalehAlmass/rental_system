import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'حول التطبيق',
        centerTitle: true,
        showShadow: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildInfoSection(context),
            const SizedBox(height: 24),
            _buildDeveloperSection(context),
            const SizedBox(height: 24),
            _buildFeaturesSection(context),
            const SizedBox(height: 24),
            _buildSupportSection(context),
            const SizedBox(height: 24),
            _buildLegalSection(context),
            const SizedBox(height: 24),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  // ================= Header =================
  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.business, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 16),
        const Text(
          'نظام التأجير',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'الإصدار 1.0.0',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  // ================= App Info =================
  Widget _buildInfoSection(BuildContext context) {
    return _buildCard(
      context,
      title: 'معلومات التطبيق',
      icon: Icons.info_outline,
      child: const Column(
        children: [
          _InfoRow(label: 'المنصة:', value: 'تطبيق جوال'),
          _InfoRow(label: 'التقنية:', value: 'Flutter'),
          _InfoRow(label: 'قاعدة البيانات:', value: 'MySQL + REST API'),
          _InfoRow(label: 'آخر تحديث:', value: '2026'),
        ],
      ),
    );
  }

  // ================= Developer =================
  Widget _buildDeveloperSection(BuildContext context) {
    return _buildCard(
      context,
      title: 'مطور التطبيق',
      icon: Icons.person,
      child: Column(
        children: [
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.engineering)),
            title: Text(
              'المهندس صالح الماس',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('مطور تطبيقات – عمل حر'),
          ),
          const Divider(),
          _buildSocialItem(
            context,
            icon: Icons.link,
            title: 'LinkedIn',
            subtitle: 'Saleh Almass',
            url: 'https://www.linkedin.com/in/salehalmass',
          ),
          _buildSocialItem(
            context,
            icon: Icons.code,
            title: 'GitHub',
            subtitle: 'Saleh Almass',
            url: 'https://github.com/SalehAlmass',
          ),
        ],
      ),
    );
  }

  // ================= Features =================
  Widget _buildFeaturesSection(BuildContext context) {
    final features = [
      'إدارة المعدات',
      'تسجيل العملاء',
      'عقود التأجير',
      'متابعة المدفوعات',
      'تقارير وتحليلات',
      'الوضع الداكن والفاتح',
      'دعم تعدد اللغات',
      'نظام أمان متكامل',
    ];

    return _buildCard(
      context,
      title: 'الميزات الرئيسية',
      icon: Icons.star_outline,
      child: Column(
        children: features
            .map(
              (f) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(f),
              ),
            )
            .toList(),
      ),
    );
  }

  // ================= Support =================
  Widget _buildSupportSection(BuildContext context) {
    return _buildCard(
      context,
      title: 'الدعم والتواصل',
      icon: Icons.support_agent,
      child: Column(
        children: [
          _buildContactItem(
            context,
            icon: Icons.email,
            title: 'البريد الإلكتروني',
            subtitle: 'salehalmass18@gmail.com',
            onTap: () => _launchEmail('salehalmass18@gmail.com'),
          ),
          _buildContactItem(
            context,
            icon: Icons.phone,
            title: 'الهاتف',
            subtitle: '+967777359678',
            onTap: () => _launchPhone('+967777359678'),
          ),
        ],
      ),
    );
  }

  // ================= Legal =================
  Widget _buildLegalSection(BuildContext context) {
    return _buildCard(
      context,
      title: 'معلومات قانونية',
      icon: Icons.gavel,
      child: Column(
        children: [
          _buildSimpleTile(context, 'سياسة الخصوصية'),
          _buildSimpleTile(context, 'شروط الاستخدام'),
          _buildSimpleTile(context, 'اتفاقية الترخيص'),
        ],
      ),
    );
  }

  // ================= Actions =================
  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _shareApp,
            icon: const Icon(Icons.share),
            label: const Text('مشاركة التطبيق'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم فتح متجر التطبيقات للتقييم')),
              );
            },
            icon: const Icon(Icons.star_border),
            label: const Text('قيّم التطبيق'),
          ),
        ),
      ],
    );
  }

  // ================= Helpers =================
  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSocialItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => _launchUrl(url),
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  Widget _buildSimpleTile(BuildContext context, String title) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: const Text('سيتم عرض المستند القانوني هنا.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Clipboard.setData(ClipboardData(text: email));
    }
  }

  void _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareApp() {
    Share.share(
      'جرّب تطبيق نظام التأجير الآن 🚀',
      subject: 'نظام التأجير',
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
