import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monojog/providers/auth_provider.dart';
import 'package:monojog/providers/focus_provider.dart';
import 'package:monojog/providers/game_provider.dart';
import 'package:monojog/providers/locale_provider.dart';
import 'package:monojog/theme/app_theme.dart';
import 'package:monojog/widgets/neu_container.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _hapticsEnabled = true;
  bool _showSecondsInWidget = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalPrefs();
  }

  Future<void> _loadLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('settings.notifications') ?? true;
      _hapticsEnabled = prefs.getBool('settings.haptics') ?? true;
      _showSecondsInWidget = prefs.getBool('settings.widget_seconds') ?? true;
      _loading = false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final focus = context.watch<FocusProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.3),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _sectionTitle('Profile'),
                NeuContainer(
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.16),
                        child: const Icon(Icons.person_rounded,
                            color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user?.displayName ??
                                  (auth.isOfflineMode
                                      ? 'Offline User'
                                      : 'Guest'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.user?.email ??
                                  (auth.isOfflineMode
                                      ? 'Local device session'
                                      : 'No email connected'),
                              style: const TextStyle(
                                color: AppTheme.darkTextSec,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await auth.signOut();
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('App Experience'),
                NeuContainer(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.language_rounded,
                            color: AppTheme.primaryColor),
                        title: const Text('Language'),
                        subtitle:
                            Text(locale.isBengali ? 'Bengali' : 'English'),
                        trailing: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'en', label: Text('EN')),
                            ButtonSegment(value: 'bn', label: Text('BN')),
                          ],
                          selected: {locale.locale},
                          onSelectionChanged: (value) {
                            locale.setLocale(value.first);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _notificationsEnabled,
                        onChanged: (v) async {
                          setState(() => _notificationsEnabled = v);
                          await _saveBool('settings.notifications', v);
                        },
                        title: const Text('Notifications'),
                        subtitle: const Text('Reminder and focus alerts'),
                        secondary: const Icon(
                            Icons.notifications_active_rounded,
                            color: AppTheme.primaryColor),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _hapticsEnabled,
                        onChanged: (v) async {
                          setState(() => _hapticsEnabled = v);
                          await _saveBool('settings.haptics', v);
                        },
                        title: const Text('Haptics'),
                        subtitle: const Text('Touch feedback and vibration'),
                        secondary: const Icon(Icons.vibration_rounded,
                            color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Focus Engine'),
                NeuContainer(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: focus.isStrictMode,
                        onChanged: focus.setStrictMode,
                        title: const Text('Strict Mode'),
                        subtitle: const Text(
                            'Prevents ending focus early without force'),
                        secondary: const Icon(Icons.lock_clock_rounded,
                            color: AppTheme.secondaryColor),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: focus.blockAllApps,
                        onChanged: focus.setBlockAllApps,
                        title: const Text('Block all apps'),
                        subtitle: const Text('Max focus mode for deep work'),
                        secondary: const Icon(Icons.block_rounded,
                            color: AppTheme.secondaryColor),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: focus.enableDND,
                        onChanged: focus.setEnableDND,
                        title: const Text('Enable DND during focus'),
                        subtitle:
                            const Text('Silence notifications while studying'),
                        secondary: const Icon(Icons.do_not_disturb_alt_rounded,
                            color: AppTheme.secondaryColor),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.timelapse_rounded,
                            color: AppTheme.secondaryColor),
                        title: const Text('Default focus duration'),
                        subtitle: Text('${focus.targetMinutes} minutes'),
                        trailing: SizedBox(
                          width: 130,
                          child: Slider(
                            value:
                                focus.targetMinutes.toDouble().clamp(15, 120),
                            min: 15,
                            max: 120,
                            divisions: 21,
                            label: '${focus.targetMinutes}m',
                            onChanged: (v) => focus.setTargetMinutes(v.round()),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.free_breakfast_rounded,
                            color: AppTheme.secondaryColor),
                        title: const Text('Short break duration'),
                        subtitle: Text('${focus.shortBreakMinutes} minutes'),
                        trailing: SizedBox(
                          width: 130,
                          child: Slider(
                            value:
                                focus.shortBreakMinutes.toDouble().clamp(3, 30),
                            min: 3,
                            max: 30,
                            divisions: 9,
                            label: '${focus.shortBreakMinutes}m',
                            onChanged: (v) =>
                                focus.setShortBreakMinutes(v.round()),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.nights_stay_rounded,
                            color: AppTheme.secondaryColor),
                        title: const Text('Long break duration'),
                        subtitle: Text('${focus.longBreakMinutes} minutes'),
                        trailing: SizedBox(
                          width: 130,
                          child: Slider(
                            value:
                                focus.longBreakMinutes.toDouble().clamp(10, 60),
                            min: 10,
                            max: 60,
                            divisions: 10,
                            label: '${focus.longBreakMinutes}m',
                            onChanged: (v) =>
                                focus.setLongBreakMinutes(v.round()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Android Home Widget'),
                NeuContainer(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _showSecondsInWidget,
                        onChanged: (v) async {
                          final focusProvider = context.read<FocusProvider>();
                          setState(() => _showSecondsInWidget = v);
                          await _saveBool('settings.widget_seconds', v);
                          await focusProvider.refreshHomeWidget();
                        },
                        title: const Text('Show seconds in widget'),
                        subtitle: const Text(
                            'Display MM:SS live-like countdown text'),
                        secondary: const Icon(Icons.widgets_rounded,
                            color: AppTheme.accentPurple),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.refresh_rounded,
                            color: AppTheme.accentPurple),
                        title: const Text('Refresh widget now'),
                        subtitle: const Text(
                            'Push latest focus state to Android home screen'),
                        onTap: () async {
                          final focusProvider = context.read<FocusProvider>();
                          final messenger = ScaffoldMessenger.of(context);
                          await focusProvider.refreshHomeWidget();
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Widget refreshed')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Data & Safety'),
                NeuContainer(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.restart_alt_rounded,
                            color: AppTheme.warningColor),
                        title: const Text('Reset all local data'),
                        subtitle:
                            const Text('Removes habits, rewards, and progress'),
                        onTap: () => _showResetDialog(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This will erase your local profile, rewards, habits, and progress. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final gameProvider = context.read<GameProvider>();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await gameProvider.resetAllData();
              if (!context.mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('All local data deleted')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
