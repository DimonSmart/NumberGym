import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../training/ui/widgets/training_background.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<PackageInfo> _packageInfoFuture;
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://dimonsmart.github.io/numbergym-privacy/',
  );
  static final Uri _repositoryUri = Uri.parse(
    'https://github.com/DimonSmart/NumberGym',
  );
  static const _nativeLinkChannel = MethodChannel(
    'com.dimonsmart.numbergym/native_links',
  );

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  Future<void> _openPrivacyPolicy() async {
    await _openExternalLink(
      _privacyPolicyUri,
      errorText: 'Could not open privacy policy link.',
    );
  }

  Future<void> _openRepository() async {
    await _openExternalLink(
      _repositoryUri,
      errorText: 'Could not open repository link.',
    );
  }

  Future<void> _openExternalLink(Uri uri, {required String errorText}) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {
      // Continue to native fallback.
    }

    if (Platform.isAndroid) {
      final opened = await _openViaNativeChannel(uri);
      if (opened) return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText)));
    }
  }

  Future<bool> _openViaNativeChannel(Uri uri) async {
    try {
      final result = await _nativeLinkChannel.invokeMethod<bool>('openUrl', {
        'url': uri.toString(),
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: TrainingBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'About',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NumberGym',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              const TextSpan(
                                text:
                                    'Is a numbers-only language trainer. It is built with a strict focus on practicing numbers, not general vocabulary, grammar, or themed lessons.\n\n'
                                    'Training is based on short cards and quick drills: you repeatedly practice the same number until it becomes automatic. Cards you answer correctly and consistently are removed from future sessions, so your practice stays focused on what still needs work.',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.35,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Буду рад сотрудничеству и обратной связи.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<PackageInfo>(
                        future: _packageInfoFuture,
                        builder: (context, snapshot) {
                          final versionText = snapshot.hasData
                              ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                              : 'Loading...';
                          return _InfoTile(
                            icon: Icons.tag_outlined,
                            label: 'App version',
                            value: versionText,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.code_outlined,
                        label: 'Repository',
                        value: 'https://github.com/DimonSmart/NumberGym',
                        onTap: _openRepository,
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy policy',
                        value: 'Open in browser',
                        onTap: _openPrivacyPolicy,
                      ),
                    ],
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.open_in_new, size: 18, color: scheme.primary),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: content,
    );
  }
}
