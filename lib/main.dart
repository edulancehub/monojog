import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:monojog/firebase_options.dart';
import 'package:monojog/theme/app_theme.dart';
import 'package:monojog/providers/auth_provider.dart';
import 'package:monojog/providers/study_provider.dart';
import 'package:monojog/providers/focus_provider.dart';
import 'package:monojog/providers/game_provider.dart';
import 'package:monojog/providers/study_room_provider.dart';
import 'package:monojog/providers/locale_provider.dart';
import 'package:monojog/providers/sleep_provider.dart';
import 'package:monojog/providers/habit_provider.dart';
import 'package:monojog/providers/task_provider.dart';
import 'package:monojog/screens/login_screen.dart';
import 'package:monojog/screens/splash_screen.dart';
import 'package:monojog/screens/home_screen.dart';
import 'package:monojog/screens/focus_screen.dart';
import 'package:monojog/screens/study_room_screen.dart';
import 'package:monojog/screens/garden_screen.dart';
import 'package:monojog/screens/my_day_screen.dart';
import 'package:monojog/screens/sleep_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.darkBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MonojogApp());
}

class MonojogApp extends StatelessWidget {
  const MonojogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudyProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => StudyRoomProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => SleepProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: MaterialApp(
        title: 'Monojog',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const _AppEntry(),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();
  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _showSplash = true;
  String? _syncedUserId;

  void _onSplashComplete() {
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return SplashScreen(onComplete: _onSplashComplete);
    return Consumer2<AuthProvider, GameProvider>(
      builder: (ctx, auth, game, _) {
        if (auth.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            game.syncProfileFromAuthUser(
              displayName: auth.user?.displayName,
              email: auth.user?.email,
            );

            final user = auth.user;
            if (user != null && _syncedUserId != user.uid) {
              _syncedUserId = user.uid;
              FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'uid': user.uid,
                'email': user.email,
                'displayName': user.displayName,
                'lastSeenAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          });
        }

        if (!auth.isAuthenticated && !auth.isOfflineMode) {
          return const LoginScreen();
        }
        return const MainScreen();
      },
    );
  }
}

// ══════════════════════════════════════════════════════
//  MAIN SCREEN
//  Tab Order: Home | Todo | Focus | Sleep | Room | Garden
// ══════════════════════════════════════════════════════
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentTab = 0;

  // Tab order: Home, Todo, Focus, Sleep, Room, Garden
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomeScreen(onSwitchTab: (i) => setState(() => _currentTab = i)),
      const MyDayScreen(),
      const FocusScreen(),
      const SleepScreen(),
      const StudyRoomScreen(),
      const GardenScreen(),
    ];
  }

  void _onTabTap(int index) {
    final focus = context.read<FocusProvider>();
    // Prevent leaving Focus tab during active session
    if (focus.isFocusActive && _currentTab == 2 && index != 2) {
      _showActiveSessionPopup(focus);
      return;
    }
    setState(() => _currentTab = index);
  }

  void _showActiveSessionPopup(FocusProvider focus) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ActiveSessionSheet(
        focus: focus,
        onGoToSession: () {
          Navigator.pop(ctx);
          setState(() => _currentTab = 2);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusProvider>(
      builder: (ctx, focus, _) {
        return Scaffold(
          extendBody: true,
          backgroundColor: AppTheme.darkBg,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                IndexedStack(index: _currentTab, children: _tabs),
                // ── Floating Active Session Banner on non-Focus tabs ──
                if (focus.isFocusActive && _currentTab != 2)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _ActiveSessionBanner(
                      focus: focus,
                      onTap: () => setState(() => _currentTab = 2),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(focus),
        );
      },
    );
  }

  Widget _buildBottomNav(FocusProvider focus) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF12121A),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: List.generate(_navData.length, (i) {
                  return _buildNavItem(i, _navData[i], focus);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, _NavData item, FocusProvider focus) {
    final isSelected = _currentTab == index;
    final hasSessionDot = index == 2 && focus.isFocusActive;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      item.color.withValues(alpha: 0.15),
                      item.color.withValues(alpha: 0.03),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      key: ValueKey('nav_${index}_$isSelected'),
                      size: 22,
                      color: isSelected
                          ? item.color
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  if (hasSessionDot)
                    Positioned(
                      top: -2,
                      right: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.successColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.successColor.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? item.color
                      : Colors.white.withValues(alpha: 0.3),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tab order: Home, Todo, Focus, Sleep, Room, Garden
  static const _navData = [
    _NavData(
        Icons.home_rounded, Icons.home_outlined, 'Home', AppTheme.primaryColor),
    _NavData(Icons.check_circle_rounded, Icons.check_circle_outlined, 'Todo',
        Color(0xFF00E5A0)),
    _NavData(Icons.rocket_launch_rounded, Icons.rocket_launch_outlined, 'Focus',
        Color(0xFF7C4DFF)),
    _NavData(Icons.nightlight_rounded, Icons.nightlight_outlined, 'Sleep',
        Color(0xFF66FFCC)),
    _NavData(Icons.meeting_room_rounded, Icons.meeting_room_outlined, 'Room',
        Color(0xFF00E5FF)),
    _NavData(
        Icons.eco_rounded, Icons.eco_outlined, 'Garden', AppTheme.successColor),
  ];
}

class _NavData {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  final Color color;
  const _NavData(this.activeIcon, this.icon, this.label, this.color);
}

// ── Floating Active Session Banner ──
class _ActiveSessionBanner extends StatelessWidget {
  final FocusProvider focus;
  final VoidCallback onTap;
  const _ActiveSessionBanner({required this.focus, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C4DFF), Color(0xFF2979FF)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                focus.isOnBreak ? 'Break Time' : 'Focus Session Active',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              focus.formattedRemainingTime,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Active Session Bottom Sheet ──
class _ActiveSessionSheet extends StatelessWidget {
  final FocusProvider focus;
  final VoidCallback onGoToSession;
  const _ActiveSessionSheet({required this.focus, required this.onGoToSession});

  @override
  Widget build(BuildContext context) {
    final minutes = focus.remainingSeconds ~/ 60;
    final seconds = focus.remainingSeconds % 60;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF16161F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C4DFF), Color(0xFF2979FF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.rocket_launch_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            focus.isOnBreak ? 'Break Time' : 'Focus Session Active',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${focus.elapsedMinutes} min focused · ${minutes}m ${seconds}s remaining',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.darkTextSec,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          // Progress bar
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: focus.progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _sheetButton(
                  label: 'Go to Session',
                  icon: Icons.arrow_forward_rounded,
                  isPrimary: true,
                  onTap: onGoToSession,
                ),
              ),
              if (!focus.isStrictMode) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _sheetButton(
                    label: 'End Session',
                    icon: Icons.stop_rounded,
                    isPrimary: false,
                    onTap: () {
                      Navigator.pop(context);
                      _confirmEnd(context, focus);
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheetButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF2979FF)],
                )
              : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isPrimary ? Colors.white : AppTheme.errorColor,
                size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : AppTheme.errorColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmEnd(BuildContext context, FocusProvider focus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('End Session?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800, color: Colors.white)),
        content: Text(
          'Ending early will cost you HP and no rewards will be given.',
          style: GoogleFonts.inter(color: AppTheme.darkTextSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Going',
                style: GoogleFonts.inter(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              focus.cancelFocusSession();
              context.read<GameProvider>().takeDamage(10);
            },
            child: Text('End',
                style: GoogleFonts.inter(
                    color: AppTheme.errorColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
