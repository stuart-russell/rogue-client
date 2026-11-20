import 'package:flutter/material.dart';

import '../state/app_model.dart';
import '../theme.dart';
import '../updates/update_controller.dart';
import '../updates/update_manifest.dart';

/// Settings → Updates: version, check button, release notes and install action.
class UpdatesPanel extends StatelessWidget {
  const UpdatesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final updates = model.updates;

    return AnimatedBuilder(
      animation: updates,
      builder: (context, _) {
        final manifest = updates.manifest;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rogue ${updates.version.semver}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _status(updates),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: updates.busy || !updates.isConfigured
                      ? null
                      : () => updates.check(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: updates.busy
                      ? SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textMuted,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Check now'),
                ),
              ],
            ),
            if (manifest != null &&
                (updates.hasUpdate || updates.phase == UpdatePhase.error))
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _ReleaseCard(updates: updates, manifest: manifest),
              ),
            if (updates.phase == UpdatePhase.staged) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: updates.restart,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 17),
                  label: const Text('Restart now'),
                ),
              ),
            ],
            if (!updates.isConfigured)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Builds from CI point ROGUE_UPDATE_MANIFEST at the release manifest; '
                  'local builds leave it unset.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _status(UpdateController updates) {
    final checked = updates.lastChecked;
    return switch (updates.phase) {
      UpdatePhase.notConfigured => 'Updates are disabled in this build.',
      UpdatePhase.idle => 'Not checked yet.',
      UpdatePhase.checking => 'Checking for updates…',
      UpdatePhase.upToDate =>
        checked == null
            ? 'You are up to date.'
            : 'You are up to date · checked ${_ago(checked)}',
      UpdatePhase.available =>
        'Version ${updates.manifest?.version} is available.',
      UpdatePhase.skipped => 'Version ${updates.manifest?.version} skipped.',
      UpdatePhase.downloading =>
        'Downloading… ${((updates.progress ?? 0) * 100).round()}%',
      UpdatePhase.staged => 'Update installed — restart to finish.',
      UpdatePhase.handedOff => 'Finish installing in the Android dialog.',
      UpdatePhase.manual =>
        'Downloaded — the update file is in the window that opened.',
      UpdatePhase.error => updates.error ?? 'Update failed.',
    };
  }

  static String _ago(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.updates, required this.manifest});

  final UpdateController updates;
  final UpdateManifest manifest;

  @override
  Widget build(BuildContext context) {
    final notes = manifest.notes;
    final downloading = updates.phase == UpdatePhase.downloading;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.arrow_circle_down_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Version ${manifest.version} of Rogue',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
              if (updates.hasUpdate && updates.phase != UpdatePhase.staged)
                TextButton(
                  onPressed: updates.busy ? null : updates.skip,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Skip this version'),
                ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 130),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Text(
                    notes,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (downloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: updates.progress,
                minHeight: 4,
                backgroundColor: AppColors.border,
                color: AppColors.accent,
              ),
            ),
          ],
          if (updates.phase == UpdatePhase.available ||
              updates.phase == UpdatePhase.skipped ||
              updates.phase == UpdatePhase.error) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: downloading ? null : updates.install,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                ),
                icon: Icon(
                  updates.canSelfInstall
                      ? Icons.download_rounded
                      : Icons.open_in_new_rounded,
                  size: 17,
                ),
                label: Text(updates.actionLabel),
              ),
            ),
          ],
          if (updates.phase == UpdatePhase.error && updates.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                updates.error!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.warning,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
