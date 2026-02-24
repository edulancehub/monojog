import 'package:flutter/material.dart' hide Badge;
import 'package:uuid/uuid.dart';
import 'package:monojog/models/user_profile.dart';
import 'package:monojog/models/habit_models.dart';
import 'package:monojog/models/reward_models.dart';
import 'package:monojog/services/database_service.dart';

class GameProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final Uuid _uuid = const Uuid();

  UserProfile _profile = UserProfile();
  List<StudyHabit> _habits = [];
  List<StudyDaily> _dailies = [];
  List<StudyTodo> _todos = [];
  List<Badge> _badges = [];
  List<RewardItem> _rewards = [];
  List<BrainDump> _brainDumps = [];

  UserProfile get profile => _profile;
  List<StudyHabit> get habits => _habits;
  List<StudyDaily> get dailies => _dailies;
  List<StudyTodo> get todos => _todos;
  List<Badge> get badges => _badges;
  List<RewardItem> get rewards => _rewards;
  List<BrainDump> get brainDumps => _brainDumps;

  int get unlockedBadgeCount => _badges.where((b) => b.isUnlocked).length;
  int get pendingTodoCount => _todos.where((t) => !t.isDone).length;
  int get pendingDailyCount => _dailies.where((d) => !d.isDoneToday).length;

  GameProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadProfile();
    await _loadHabits();
    await _loadDailies();
    await _loadTodos();
    await _initBadges();
    await _loadBadges();
    await _initRewards();
    await _loadRewards();
    await _loadBrainDumps();
    _resetDailiesIfNewDay();
  }

  // ============ PROFILE ============
  Future<void> _loadProfile() async {
    final data = await _db.getUserProfile();
    _profile = UserProfile.fromMap(data);
    notifyListeners();
  }

  Future<void> _saveProfile() async {
    await _db.updateUserProfile(_profile.toMap());
    notifyListeners();
  }

  Future<void> updateProfile(
      {String? username, String? avatarType, String? profileImagePath}) async {
    _profile = _profile.copyWith(
      username: username ?? _profile.username,
      avatarType: avatarType ?? _profile.avatarType,
      profileImagePath: profileImagePath ?? _profile.profileImagePath,
    );
    await _saveProfile();
  }

  Future<void> syncProfileFromAuthUser({String? displayName, String? email}) async {
    final preferredName = _preferredName(displayName, email);
    if (preferredName == null) return;

    final currentName = _profile.username.trim();
    final shouldReplace =
        currentName.isEmpty || currentName.toLowerCase() == 'student';

    if (!shouldReplace || currentName == preferredName) return;

    _profile = _profile.copyWith(username: preferredName);
    await _saveProfile();
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

    final base = cleanEmail.split('@').first.trim();
    if (base.isEmpty) return null;

    final normalized = base
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1).toLowerCase() : ''}')
        .join(' ')
        .trim();

    return normalized.isEmpty ? null : normalized;
  }

  Future<void> addGold(int amount) async {
    _profile = _profile.copyWith(gold: _profile.gold + amount);
    await _saveProfile();
  }

  Future<void> spendGold(int amount) async {
    if (_profile.gold >= amount) {
      _profile = _profile.copyWith(gold: _profile.gold - amount);
      await _saveProfile();
    }
  }

  Future<void> addExperience(int xp) async {
    int newXp = _profile.experience + xp;
    int newLevel = _profile.level;
    int xpToNext = _profile.experienceToNext;

    while (newXp >= xpToNext) {
      newXp -= xpToNext;
      newLevel++;
      xpToNext = UserProfile.xpForLevel(newLevel);
    }

    _profile = _profile.copyWith(
      experience: newXp,
      experienceToNext: xpToNext,
      level: newLevel,
      totalPoints: _profile.totalPoints + xp,
    );
    await _saveProfile();

    // Check level badges
    if (newLevel >= 10) await _tryUnlockBadge('level_10');
  }

  Future<void> takeDamage(int amount) async {
    final newHealth = (_profile.health - amount).clamp(0, _profile.maxHealth);
    _profile = _profile.copyWith(health: newHealth);
    await _saveProfile();
  }

  Future<void> heal(int amount) async {
    final newHealth = (_profile.health + amount).clamp(0, _profile.maxHealth);
    _profile = _profile.copyWith(health: newHealth);
    await _saveProfile();
  }

  Future<void> updateStreak(int streak) async {
    final longest =
        streak > _profile.longestStreak ? streak : _profile.longestStreak;
    _profile = _profile.copyWith(currentStreak: streak, longestStreak: longest);
    await _saveProfile();

    if (streak >= 3) await _tryUnlockBadge('streak_3');
    if (streak >= 7) await _tryUnlockBadge('streak_7');
    if (streak >= 14) await _tryUnlockBadge('streak_14');
    if (streak >= 30) await _tryUnlockBadge('streak_30');
  }

  /// Called when a focus session completes
  Future<void> onSessionComplete(
      {int minutes = 0, bool noUnlocks = false}) async {
    final points = minutes * 2; // 2 gold per minute
    final xp = minutes; // 1 xp per minute
    int bonus = 0;

    if (noUnlocks) {
      bonus += 10; // bonus for no phone unlocks
      await _tryUnlockBadge('deep_focus');
    }
    if (minutes >= 60) {
      await _tryUnlockBadge('hour_warrior');
    }

    final hour = DateTime.now().hour;
    if (hour < 6) await _tryUnlockBadge('early_bird');
    if (hour >= 0 && hour < 5) await _tryUnlockBadge('night_owl');

    _profile = _profile.copyWith(
      sessionsCompleted: _profile.sessionsCompleted + 1,
      totalStudyMinutes: _profile.totalStudyMinutes + minutes,
    );
    await _saveProfile();

    await addGold(points + bonus);
    await addExperience(xp + (bonus ~/ 2));

    if (_profile.sessionsCompleted >= 1) await _tryUnlockBadge('first_focus');
    if (_profile.sessionsCompleted >= 50) await _tryUnlockBadge('sessions_50');
  }

  // ============ HABITS ============
  Future<void> _loadHabits() async {
    final data = await _db.getHabits();
    _habits = data.map((m) => StudyHabit.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addHabit(String title,
      {String? notes, bool isPositive = true, int difficulty = 2}) async {
    final habit = StudyHabit(
      id: _uuid.v4(),
      title: title,
      notes: notes,
      isPositive: isPositive,
      difficulty: difficulty,
    );
    await _db.insertHabit(habit.toMap());
    await _loadHabits();
  }

  Future<void> tapHabitPositive(String id) async {
    final habit = _habits.firstWhere((h) => h.id == id);
    final updated = habit.copyWith(
      counterUp: habit.counterUp + 1,
      streak: habit.streak + 1,
    );
    await _db.updateHabit(id, updated.toMap());
    await addGold(habit.pointsPerTap);
    await addExperience(habit.pointsPerTap ~/ 2);
    await heal(1);
    await _loadHabits();
  }

  Future<void> tapHabitNegative(String id) async {
    final habit = _habits.firstWhere((h) => h.id == id);
    final updated = habit.copyWith(
      counterDown: habit.counterDown + 1,
      streak: 0,
    );
    await _db.updateHabit(id, updated.toMap());
    await takeDamage(habit.pointsPerTap);
    await _loadHabits();
  }

  Future<void> deleteHabit(String id) async {
    await _db.deleteHabit(id);
    await _loadHabits();
  }

  Future<void> tapHabit(String id, bool positive) async {
    if (positive) {
      await tapHabitPositive(id);
    } else {
      await tapHabitNegative(id);
    }
  }

  // ============ DAILIES ============
  Future<void> _loadDailies() async {
    final data = await _db.getDailies();
    _dailies = data.map((m) => StudyDaily.fromMap(m)).toList();
    notifyListeners();
  }

  void _resetDailiesIfNewDay() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    for (final d in _dailies) {
      if (d.lastCompletedDate != today && d.isDoneToday) {
        _db.updateDaily(d.id, d.copyWith(isDoneToday: false).toMap());
      }
    }
    _loadDailies();
  }

  Future<void> addDaily(String title,
      {String? notes, int targetMinutes = 30, int difficulty = 2}) async {
    final daily = StudyDaily(
      id: _uuid.v4(),
      title: title,
      notes: notes,
      targetMinutes: targetMinutes,
      difficulty: difficulty,
    );
    await _db.insertDaily(daily.toMap());
    await _loadDailies();
  }

  Future<void> completeDaily(String id) async {
    final daily = _dailies.firstWhere((d) => d.id == id);
    final today = DateTime.now().toIso8601String().split('T')[0];
    final updated = daily.copyWith(
      isDoneToday: true,
      streak: daily.streak + 1,
      lastCompletedDate: today,
    );
    await _db.updateDaily(id, updated.toMap());

    final goldEarned = daily.difficulty * 5;
    await addGold(goldEarned);
    await addExperience(goldEarned ~/ 2);
    await heal(2);
    await _loadDailies();
  }

  Future<void> uncompleteDaily(String id) async {
    final daily = _dailies.firstWhere((d) => d.id == id);
    final updated = daily.copyWith(isDoneToday: false);
    await _db.updateDaily(id, updated.toMap());
    await _loadDailies();
  }

  Future<void> toggleDaily(String id) async {
    final daily = _dailies.firstWhere((d) => d.id == id);
    if (daily.isDoneToday) {
      await uncompleteDaily(id);
    } else {
      await completeDaily(id);
    }
  }

  Future<void> deleteDaily(String id) async {
    await _db.deleteDaily(id);
    await _loadDailies();
  }

  // ============ TODOS ============
  Future<void> _loadTodos() async {
    final data = await _db.getTodos();
    _todos = data.map((m) => StudyTodo.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addTodo(String title,
      {String? notes, String? dueDate, int difficulty = 2}) async {
    final todo = StudyTodo(
      id: _uuid.v4(),
      title: title,
      notes: notes,
      dueDate: dueDate,
      difficulty: difficulty,
    );
    await _db.insertTodo(todo.toMap());
    await _loadTodos();
  }

  Future<void> completeTodo(String id) async {
    final todo = _todos.firstWhere((t) => t.id == id);
    final updated = todo.copyWith(isDone: true);
    await _db.updateTodo(id, updated.toMap());

    final goldEarned = todo.difficulty * 8;
    await addGold(goldEarned);
    await addExperience(goldEarned ~/ 2);
    await _loadTodos();
  }

  Future<void> uncompleteTodo(String id) async {
    final todo = _todos.firstWhere((t) => t.id == id);
    final updated = todo.copyWith(isDone: false);
    await _db.updateTodo(id, updated.toMap());
    await _loadTodos();
  }

  Future<void> toggleTodo(String id) async {
    final todo = _todos.firstWhere((t) => t.id == id);
    if (todo.isDone) {
      await uncompleteTodo(id);
    } else {
      await completeTodo(id);
    }
  }

  Future<void> deleteTodo(String id) async {
    await _db.deleteTodo(id);
    await _loadTodos();
  }

  // ============ BADGES ============
  Future<void> _initBadges() async {
    for (final badge in Badge.allBadges) {
      await _db.insertBadge(badge.toMap());
    }
  }

  Future<void> _loadBadges() async {
    final data = await _db.getBadges();
    _badges = data.map((m) => Badge.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> _tryUnlockBadge(String id) async {
    final badge = _badges.firstWhere((b) => b.id == id,
        orElse: () => Badge(id: '', title: '', description: '', icon: ''));
    if (badge.id.isEmpty || badge.isUnlocked) return;
    await _db.unlockBadge(id);
    await addGems(5);
    await _loadBadges();
  }

  Future<void> addGems(int amount) async {
    _profile = _profile.copyWith(gems: _profile.gems + amount);
    await _saveProfile();
  }

  // ============ REWARDS ============
  Future<void> _initRewards() async {
    for (final reward in RewardItem.defaultRewards) {
      await _db.insertReward(reward.toMap());
    }
  }

  Future<void> _loadRewards() async {
    final data = await _db.getRewards();
    _rewards = data.map((m) => RewardItem.fromMap(m)).toList();
    notifyListeners();
  }

  Future<bool> purchaseReward(String id) async {
    final reward = _rewards.firstWhere((r) => r.id == id);
    if (_profile.gold >= reward.cost) {
      await spendGold(reward.cost);
      await _loadRewards();
      return true;
    }
    return false;
  }

  Future<void> addCustomReward(
      String name, String description, String icon, int cost) async {
    final reward = RewardItem(
      id: _uuid.v4(),
      name: name,
      description: description,
      icon: icon,
      cost: cost,
      type: 'custom',
    );
    await _db.insertReward(reward.toMap());
    await _loadRewards();
  }

  Future<void> deleteReward(String id) async {
    await _db.deleteReward(id);
    await _loadRewards();
  }

  // ============ BRAIN DUMPS ============
  Future<void> _loadBrainDumps() async {
    final data = await _db.getBrainDumps();
    _brainDumps = data.map((m) => BrainDump.fromMap(m)).toList();
    notifyListeners();
  }

  Future<void> addBrainDump(String text,
      {String? sessionId, String type = 'general'}) async {
    final dump = BrainDump(
      id: _uuid.v4(),
      text: text,
      sessionId: sessionId,
      type: type,
    );
    await _db.insertBrainDump(dump.toMap());
    await _loadBrainDumps();
  }

  Future<void> deleteBrainDump(String id) async {
    await _db.deleteBrainDump(id);
    await _loadBrainDumps();
  }

  /// Apply penalties for missed dailies (called at end of day)
  Future<void> applyDailyPenalties() async {
    final missed = _dailies.where((d) => !d.isDoneToday).length;
    if (missed > 0) {
      await takeDamage(missed * 3);
    }
  }

  /// Anti-cheat: penalize for app switch during focus
  Future<void> penalizeAppSwitch() async {
    await takeDamage(2);
    if (_profile.gold > 0) {
      _profile = _profile.copyWith(gold: (_profile.gold - 1).clamp(0, 999999));
      await _saveProfile();
    }
  }

  Future<void> resetAll() async {
    await _db.deleteAllData();
    await _initialize();
  }

  Future<void> resetAllData() async {
    await resetAll();
  }
}
