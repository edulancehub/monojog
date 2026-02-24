import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:monojog/providers/game_provider.dart';
import 'package:monojog/providers/auth_provider.dart';
import 'package:monojog/providers/focus_provider.dart';
import 'package:monojog/providers/habit_provider.dart';
import 'package:monojog/providers/locale_provider.dart';
import 'package:monojog/theme/app_theme.dart';
import 'package:monojog/screens/habits_screen.dart';
import 'package:monojog/screens/brain_dump_screen.dart';
import 'package:monojog/screens/blocked_apps_screen.dart';
import 'package:monojog/screens/subjects_screen.dart';
import 'package:monojog/screens/session_history_screen.dart';
import 'package:monojog/screens/sleep_screen.dart';
import 'package:monojog/screens/settings_screen.dart';
import 'package:monojog/screens/task_screen.dart';
import 'package:monojog/screens/my_day_screen.dart';
import 'package:monojog/providers/task_provider.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int)? onSwitchTab;
  const HomeScreen({super.key, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final auth = context.watch<AuthProvider>();
    final focus = context.watch<FocusProvider>();
    final habitProv = context.watch<HabitProvider>();
    final locale = context.watch<LocaleProvider>();
    final profile = game.profile;
    final displayName =
      _resolveDisplayName(profile.username, auth.user?.displayName, auth.user?.email);

    return CustomScrollView(
      slivers: [
        // ── Sliver App Bar ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: () => _showProfileEditSheet(context, profile, game),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: profile.profileImagePath == null
                          ? AppTheme.premiumGradient
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      image: profile.profileImagePath != null
                          ? DecorationImage(
                              image: FileImage(File(profile.profileImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: profile.profileImagePath == null
                        ? Center(
                            child: Text(
                              _avatarEmoji(profile.avatarType),
                              style: const TextStyle(fontSize: 22),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greetingText(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.darkTextSec,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Streak badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.goldColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        '${profile.currentStreak}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.goldColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Settings
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen())),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.settings_outlined,
                        color: Colors.white.withValues(alpha: 0.7), size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Spacing ──
        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // ── Level & XP Card ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _LevelCard(profile: profile),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // ── Quick Stats ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.timer_rounded,
                  value: '${profile.totalFocusMinutes}',
                  unit: 'min',
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.check_circle_rounded,
                  value: '${profile.sessionsCompleted}',
                  unit: 'done',
                  color: AppTheme.successColor,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.monetization_on_rounded,
                  value: '${profile.gold}',
                  unit: 'gold',
                  color: AppTheme.goldColor,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.diamond_rounded,
                  value: '${profile.gems}',
                  unit: 'gems',
                  color: const Color(0xFFE040FB),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Today's Habits ──
        if (habitProv.scheduledTodayCount() > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HabitsScreen())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF7C4DFF).withValues(alpha: 0.08),
                        const Color(0xFF00E5A0).withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.04)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: habitProv.todayProgress,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.06),
                              valueColor: AlwaysStoppedAnimation(
                                  habitProv.todayProgress >= 1.0
                                      ? AppTheme.goldColor
                                      : const Color(0xFF00E5A0)),
                              strokeWidth: 4,
                              strokeCap: StrokeCap.round,
                            ),
                            Center(
                              child: Text(
                                habitProv.todayProgress >= 1.0
                                    ? '🎉'
                                    : '${(habitProv.todayProgress * 100).round()}%',
                                style: GoogleFonts.inter(
                                  fontSize:
                                      habitProv.todayProgress >= 1.0 ? 16 : 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Habits',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${habitProv.completedTodayCount()} of ${habitProv.scheduledTodayCount()} done',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.darkTextSec,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.3), size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Quick Actions ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Quick Actions',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ── Start Focus CTA ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _StartFocusCTA(focus: focus, onSwitchTab: onSwitchTab),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        // ── My Day Quick Card ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _MyDayQuickCard(
              taskProvider: context.watch<TaskProvider>(),
              habitProvider: habitProv,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // ── Section Title ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Tools & Features',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ── Feature Grid ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: _buildFeatureGrid(context, locale),
        ),
      ],
    );
  }

  String _resolveDisplayName(String localName, String? authName, String? authEmail) {
    final local = localName.trim();
    if (local.isNotEmpty && local.toLowerCase() != 'student') return local;

    final fromAuth = _preferredName(authName, authEmail);
    if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;

    return local.isEmpty ? 'Friend' : local;
  }

  String? _preferredName(String? displayName, String? email) {
    final cleanDisplay = displayName?.trim();
    if (cleanDisplay != null && cleanDisplay.isNotEmpty) {
      return cleanDisplay.split(RegExp(r'\s+')).first;
    }

    final cleanEmail = email?.trim();
    if (cleanEmail == null || cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return null;
    }

    final value = cleanEmail.split('@').first.trim();
    if (value.isEmpty) return null;
    return '${value[0].toUpperCase()}${value.length > 1 ? value.substring(1) : ''}';
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 🌅';
    if (hour < 17) return 'Good Afternoon ☀️';
    if (hour < 21) return 'Good Evening 🌆';
    return 'Good Night 🌙';
  }

  void _showProfileEditSheet(
      BuildContext context, dynamic profile, GameProvider game) {
    final nameController = TextEditingController(text: profile.username);
    String selectedAvatar = profile.avatarType;
    String? imagePath = profile.profileImagePath;
    final avatars = ['warrior', 'mage', 'healer', 'rogue'];
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customize Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Profile Image
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final source = await showDialog<ImageSource>(
                      context: ctx,
                      builder: (c) => SimpleDialog(
                        backgroundColor: AppTheme.darkBg,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Choose Photo',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        children: [
                          SimpleDialogOption(
                            onPressed: () =>
                                Navigator.pop(c, ImageSource.camera),
                            child: const Row(
                              children: [
                                Icon(Icons.camera_alt_rounded,
                                    color: AppTheme.primaryColor),
                                SizedBox(width: 12),
                                Text('Take Photo',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          SimpleDialogOption(
                            onPressed: () =>
                                Navigator.pop(c, ImageSource.gallery),
                            child: const Row(
                              children: [
                                Icon(Icons.photo_library_rounded,
                                    color: AppTheme.successColor),
                                SizedBox(width: 12),
                                Text('From Gallery',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                    if (source == null) return;
                    final picked = await picker.pickImage(
                      source: source,
                      maxWidth: 512,
                      maxHeight: 512,
                      imageQuality: 80,
                    );
                    if (picked != null) {
                      setState(() => imagePath = picked.path);
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: imagePath == null
                              ? AppTheme.premiumGradient
                              : null,
                          image: imagePath != null
                              ? DecorationImage(
                                  image: FileImage(File(imagePath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                        child: imagePath == null
                            ? Center(
                                child: Text(
                                  _avatarEmoji(selectedAvatar),
                                  style: const TextStyle(fontSize: 40),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppTheme.darkCard, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Avatar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkTextSec,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: avatars.map((type) {
                  final isSelected = selectedAvatar == type;
                  return GestureDetector(
                    onTap: () => setState(() {
                      selectedAvatar = type;
                      imagePath = null; // clear image when avatar selected
                    }),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.2)
                            : AppTheme.darkBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _avatarEmoji(type),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your Name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkTextSec,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.darkBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Enter your name',
                  hintStyle: const TextStyle(color: AppTheme.darkTextSec),
                  prefixIcon: const Icon(Icons.person_outline,
                      color: AppTheme.darkTextSec),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    game.updateProfile(
                      username: nameController.text.trim(),
                      avatarType: selectedAvatar,
                      profileImagePath: imagePath,
                    );
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _avatarEmoji(String type) {
    switch (type) {
      case 'mage':
        return '🧙';
      case 'healer':
        return '🧑‍⚕️';
      case 'rogue':
        return '🥷';
      default:
        return '⚔️';
    }
  }

  Widget _buildFeatureGrid(BuildContext context, LocaleProvider locale) {
    final features = [
      _Feature(
          Icons.today_rounded,
          'My Day',
          'Tasks + Habits',
          const [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
          () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const MyDayScreen()))),
      _Feature(
          Icons.checklist_rounded,
          'Tasks',
          'Manage to-dos',
          const [Color(0xFFFF9F43), Color(0xFFFF6B6B)],
          () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const TaskScreen()))),
      _Feature(
          Icons.repeat_rounded,
          'Habits',
          'Build consistency',
          const [Color(0xFF7C4DFF), Color(0xFFE040FB)],
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HabitsScreen()))),
      _Feature(
          Icons.psychology_rounded,
          'Brain Dump',
          'Clear your mind',
          const [Color(0xFFFF6B6B), Color(0xFFFF9F43)],
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BrainDumpScreen()))),
      _Feature(
          Icons.block_rounded,
          'App Blocker',
          'Stay distraction-free',
          const [Color(0xFF00F5D4), Color(0xFF00BBD4)],
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BlockedAppsScreen()))),
      _Feature(
          Icons.school_rounded,
          'Subjects',
          'Track your courses',
          const [Color(0xFFFEE440), Color(0xFFF77F00)],
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubjectsScreen()))),
      _Feature(
          Icons.history_rounded,
          'History',
          'Past sessions',
          const [Color(0xFF2979FF), Color(0xFF7C4DFF)],
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SessionHistoryScreen()))),
      _Feature(
          Icons.nights_stay_rounded,
          'Sleep',
          'Sleep management',
          const [Color(0xFF00E5FF), Color(0xFF2979FF)],
          () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SleepScreen()))),
    ];

    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: features.length,
      itemBuilder: (ctx, i) => _FeatureCard(feature: features[i]),
    );
  }
}

// ── Level Card ──
class _LevelCard extends StatelessWidget {
  final dynamic profile;
  const _LevelCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final xpProgress = profile.experienceToNext > 0
        ? (profile.experience / profile.experienceToNext).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E2E), Color(0xFF16161F)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Level badge
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${profile.level}',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'LVL',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.levelTitleBengali,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.experience} / ${profile.experienceToNext} XP',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkTextSec,
                      ),
                    ),
                  ],
                ),
              ),
              // Health
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('❤️', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${profile.health}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.healthRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'HP',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkTextSec,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // XP progress bar
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: xpProgress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: AppTheme.premiumGradient,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stat Chip ──
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              unit,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkTextSec,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Start Focus CTA ──
class _StartFocusCTA extends StatelessWidget {
  final FocusProvider focus;
  final void Function(int)? onSwitchTab;
  const _StartFocusCTA({required this.focus, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    if (focus.isFocusActive) {
      // Show active session card instead
      return GestureDetector(
        onTap: () {
          if (onSwitchTab != null) {
            onSwitchTab!(2);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1040), Color(0xFF16161F)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF2979FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session In Progress',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${focus.formattedRemainingTime} remaining',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7C4DFF),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white70, size: 20),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (onSwitchTab != null) {
          onSwitchTab!(2);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2940), Color(0xFF0F1520)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Focus Session',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to begin deep focus mode',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.darkTextSec,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'GO',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature Model ──
class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  _Feature(this.icon, this.title, this.subtitle, this.gradient, this.onTap);
}

// ── Feature Card ──
class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});
  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        f.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: f.gradient[0].withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: f.gradient[0].withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      f.gradient[0].withValues(alpha: 0.2),
                      f.gradient[1].withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(f.icon, color: f.gradient[0], size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                f.title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                f.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkTextSec,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── My Day Quick Card ──
class _MyDayQuickCard extends StatelessWidget {
  final TaskProvider taskProvider;
  final HabitProvider habitProvider;
  const _MyDayQuickCard(
      {required this.taskProvider, required this.habitProvider});

  @override
  Widget build(BuildContext context) {
    final todayTasks = taskProvider.todayActiveCount;
    final todayDone = taskProvider.todayDoneCount;
    final habitsScheduled = habitProvider.scheduledTodayCount();
    final habitsDone = habitProvider.completedTodayCount();
    final totalActive = todayTasks + habitsScheduled;
    final totalDone = todayDone + habitsDone;

    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const MyDayScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00E5FF).withValues(alpha: 0.08),
              const Color(0xFF7C4DFF).withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.today_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Day',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalActive == 0
                        ? 'No items for today'
                        : '$totalDone/$totalActive done • ${todayTasks}T ${habitsScheduled}H',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.darkTextSec,
                    ),
                  ),
                ],
              ),
            ),
            if (totalActive > 0)
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: totalActive > 0 ? totalDone / totalActive : 0,
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(
                    totalDone >= totalActive
                        ? AppTheme.goldColor
                        : const Color(0xFF00E5FF),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.3), size: 22),
          ],
        ),
      ),
    );
  }
}
