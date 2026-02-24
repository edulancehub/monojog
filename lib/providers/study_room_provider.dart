import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:monojog/models/study_room.dart';
import 'package:monojog/providers/focus_provider.dart';
import 'package:monojog/services/history_service.dart';

class StudyRoomProvider with ChangeNotifier {
  StudyRoomProvider();

  final Uuid _uuid = const Uuid();

  static final Map<String, StudyCommunity> _communityHubByCode = {};
  static final Map<String, StudyRoom> _roomHubByCode = {};
  static final Map<String, List<RoomMessage>> _roomMessagesByRoomId = {};
  static final Map<String, List<RoomMessage>> _communityMessagesByCode = {};

  StudyCommunity? _joinedCommunity;
  StudyRoom? _currentRoom;
  List<RoomMessage> _messages = [];
  List<RoomMessage> _communityMessages = [];
  Timer? _studyTimer;
  int _myStudySeconds = 0;
  bool _isStudying = false;
  bool _isSoloMode = false;

  String? _cachedGuestId;

  static final Map<String, List<CommunityNotice>> _noticesByCommunity = {};

  StudyCommunity? get joinedCommunity => _joinedCommunity;
  List<StudyCommunity> get allCommunities {
    final list = _communityHubByCode.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  StudyRoom? get currentRoom => _currentRoom;
  List<RoomMessage> get messages => List.unmodifiable(_messages);
  List<RoomMessage> get communityMessages =>
      List.unmodifiable(_communityMessages);
  int get myStudySeconds => _myStudySeconds;
  bool get isStudying => _isStudying;
  bool get isSoloMode => _isSoloMode;
  bool get isInRoom => _currentRoom != null;
  bool get hasCommunity => _joinedCommunity != null;

  /// Get notices for current community (pinned first, then by date)
  List<CommunityNotice> get notices {
    if (_joinedCommunity == null) return [];
    final list = List<CommunityNotice>.from(
        _noticesByCommunity[_joinedCommunity!.code] ?? []);
    list.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Get active rooms for a community
  List<StudyRoom> getCommunityRooms(String communityCode) {
    final community = _communityHubByCode[communityCode];
    if (community == null) return [];
    final rooms = <StudyRoom>[];
    for (final roomId in community.roomIds) {
      final room = _roomHubByCode.values.where((r) => r.id == roomId).toList();
      if (room.isNotEmpty && room.first.isActive) {
        rooms.add(room.first);
      }
    }
    return rooms;
  }

  /// All active rooms (for discovery)
  List<StudyRoom> get allActiveRooms {
    return _roomHubByCode.values.where((r) => r.isActive).toList();
  }

  /// Check if current user is admin/owner of the community
  bool get isCommunityAdmin {
    return _joinedCommunity?.ownerId == myUserId;
  }

  String get myUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return user.uid;
    _cachedGuestId ??= 'guest_${_uuid.v4().substring(0, 8)}';
    return _cachedGuestId!;
  }

  String get _myDisplayName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'Guest';
  }

  String get formattedTimer {
    final h = _myStudySeconds ~/ 3600;
    final m = (_myStudySeconds % 3600) ~/ 60;
    final s = _myStudySeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get inviteCode => _currentRoom?.roomCode ?? '';

  String buildInviteLink() {
    if (_currentRoom == null) return '';
    return 'https://monojog.app/invite?code=${_currentRoom!.roomCode}';
  }

  String? extractInviteCode(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;

    if (value.length == 6 && RegExp(r'^[A-Z0-9]{6}$').hasMatch(value)) {
      return value;
    }

    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    final fromQuery = uri.queryParameters['code'];
    if (fromQuery != null && RegExp(r'^[A-Z0-9]{6}$').hasMatch(fromQuery)) {
      return fromQuery;
    }

    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      final candidate = segments.last.toUpperCase();
      if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  Future<StudyCommunity> createCommunity({required String name}) async {
    final now = DateTime.now();
    final code = _generateUniqueCommunityCode();

    final me = RoomMember(
      id: myUserId,
      name: _myDisplayName,
      isOnline: true,
      isStudying: false,
      joinedAt: now,
    );

    final community = StudyCommunity(
      id: _uuid.v4(),
      name: name,
      code: code,
      ownerId: myUserId,
      ownerName: _myDisplayName,
      createdAt: now,
      members: [me],
      roomIds: const [],
    );

    _communityHubByCode[code] = community;
    _communityMessagesByCode.putIfAbsent(code, () => []);
    _joinedCommunity = community;
    _communityMessages = _communityMessagesByCode[code] ?? [];
    _addCommunitySystemMessage(
      code,
      'Community "$name" created by $_myDisplayName',
    );
    notifyListeners();
    return community;
  }

  Future<bool> joinCommunity(String code) async {
    final community = _communityHubByCode[code.toUpperCase()];
    if (community == null) return false;

    final alreadyMember = community.members.any((m) => m.id == myUserId);
    final updatedMembers = <RoomMember>[...community.members];
    if (!alreadyMember) {
      updatedMembers.add(RoomMember(
        id: myUserId,
        name: _myDisplayName,
        isOnline: true,
        isStudying: false,
        joinedAt: DateTime.now(),
      ));
    }

    final updatedCommunity = community.copyWith(members: updatedMembers);
    _communityHubByCode[community.code] = updatedCommunity;
    _joinedCommunity = updatedCommunity;
    _communityMessagesByCode.putIfAbsent(community.code, () => []);
    _communityMessages = _communityMessagesByCode[community.code] ?? [];
    if (!alreadyMember) {
      _addCommunitySystemMessage(
        community.code,
        '$_myDisplayName joined the community 👋',
      );
    }
    notifyListeners();
    return true;
  }

  bool openCommunity(String code) {
    final community = _communityHubByCode[code.toUpperCase()];
    if (community == null) return false;
    _joinedCommunity = community;
    _communityMessagesByCode.putIfAbsent(community.code, () => []);
    _communityMessages = _communityMessagesByCode[community.code] ?? [];
    notifyListeners();
    return true;
  }

  void sendCommunityMessage(String text) {
    final community = _joinedCommunity;
    if (community == null || text.trim().isEmpty) return;

    final msg = RoomMessage(
      id: _uuid.v4(),
      roomId: community.code,
      senderId: myUserId,
      senderName: _myDisplayName,
      text: text.trim(),
      timestamp: DateTime.now(),
      type: MessageType.text,
    );

    final list = _communityMessagesByCode[community.code] ?? [];
    list.add(msg);
    _communityMessagesByCode[community.code] = list;
    _communityMessages = list;
    notifyListeners();
  }

  Future<StudyRoom> createRoom({
    required String name,
    String? subject,
    int targetMinutes = 60,
    String? communityCode,
  }) async {
    final roomCode = _generateUniqueRoomCode();
    final now = DateTime.now();

    final me = RoomMember(
      id: myUserId,
      name: _myDisplayName,
      isOnline: true,
      isStudying: false,
      joinedAt: now,
    );

    // Use provided community code, or joined community, or null (standalone room)
    final effectiveCommunityCode = communityCode ?? _joinedCommunity?.code;

    final room = StudyRoom(
      id: _uuid.v4(),
      name: name,
      hostId: myUserId,
      hostName: _myDisplayName,
      roomCode: roomCode,
      members: [me],
      createdAt: now,
      subject: subject,
      targetMinutes: targetMinutes,
      communityCode: effectiveCommunityCode,
    );

    _roomHubByCode[roomCode] = room;
    _roomMessagesByRoomId[room.id] = [];

    // If linked to a community, add room to community's room list
    if (effectiveCommunityCode != null) {
      final community = _communityHubByCode[effectiveCommunityCode];
      if (community != null) {
        final updatedCommunity = community.copyWith(
          roomIds: [...community.roomIds, room.id],
        );
        _communityHubByCode[community.code] = updatedCommunity;
        if (_joinedCommunity?.code == community.code) {
          _joinedCommunity = updatedCommunity;
        }
        _addCommunitySystemMessage(
          community.code,
          '$_myDisplayName created room "$name" 🎉',
        );
      }
    }

    _isSoloMode = false;
    _currentRoom = room;
    _messages = _roomMessagesByRoomId[room.id] ?? [];

    _addSystemMessage('Room created by $_myDisplayName 🎉');
    _addSystemMessage('Room Code: $roomCode — share to invite members');

    notifyListeners();
    return room;
  }

  /// Create a solo room (just the user, no community)
  Future<StudyRoom> createSoloRoom({
    String? subject,
    int targetMinutes = 60,
  }) async {
    final room = await createRoom(
      name: '$_myDisplayName\'s Solo Room',
      subject: subject,
      targetMinutes: targetMinutes,
    );
    _isSoloMode = true;
    notifyListeners();
    return room;
  }

  Future<bool> joinRoom(String roomCode) async {
    final normalizedCode = roomCode.toUpperCase();
    final room = _roomHubByCode[normalizedCode];
    if (room == null) return false;

    if (room.communityCode != null) {
      final community = _communityHubByCode[room.communityCode!];
      if (community == null) return false;
      final isMember = community.members.any((m) => m.id == myUserId);
      if (!isMember) {
        final joined = await joinCommunity(community.code);
        if (!joined) return false;
      }
    }

    final existingMember = room.members.any((m) => m.id == myUserId);
    final updatedMembers = <RoomMember>[...room.members];
    if (!existingMember) {
      updatedMembers.add(RoomMember(
        id: myUserId,
        name: _myDisplayName,
        isOnline: true,
        isStudying: false,
        joinedAt: DateTime.now(),
      ));
    }

    final updatedRoom = room.copyWith(members: updatedMembers, isActive: true);
    _roomHubByCode[normalizedCode] = updatedRoom;

    _currentRoom = updatedRoom;
    _messages = _roomMessagesByRoomId[updatedRoom.id] ?? [];
    _addSystemMessage('$_myDisplayName joined the room 👋');

    notifyListeners();
    return true;
  }

  void leaveRoom() {
    if (_currentRoom == null) return;

    stopStudyTimer();
    final room = _currentRoom!;

    final remainingMembers =
        room.members.where((m) => m.id != myUserId).toList();
    final hostAfterLeave =
        remainingMembers.isNotEmpty ? remainingMembers.first : null;

    final updatedRoom = room.copyWith(
      members: remainingMembers,
      isActive: remainingMembers.isNotEmpty,
      hostId: hostAfterLeave?.id ?? room.hostId,
      hostName: hostAfterLeave?.name ?? room.hostName,
    );

    _roomHubByCode[room.roomCode] = updatedRoom;
    _addSystemMessage('$_myDisplayName left the room');

    _currentRoom = null;
    _messages = [];
    _isSoloMode = false;
    notifyListeners();
  }

  void sendMessage(String text) {
    if (_currentRoom == null || text.trim().isEmpty) return;

    final msg = RoomMessage(
      id: _uuid.v4(),
      roomId: _currentRoom!.id,
      senderId: myUserId,
      senderName: _myDisplayName,
      text: text.trim(),
      timestamp: DateTime.now(),
      type: MessageType.text,
    );

    final roomMessages = _roomMessagesByRoomId[_currentRoom!.id] ?? [];
    roomMessages.add(msg);
    _roomMessagesByRoomId[_currentRoom!.id] = roomMessages;
    _messages = roomMessages;
    notifyListeners();
  }

  void pokeMember(String memberId) {
    if (_currentRoom == null) return;
    final member =
        _currentRoom!.members.where((m) => m.id == memberId).toList();
    if (member.isEmpty || member.first.id == myUserId) return;
    _addSystemMessage(
        '$_myDisplayName poked ${member.first.name} to study now! 🔔');
    notifyListeners();
  }

  void startStudyTimer() {
    if (_isStudying || _currentRoom == null) return;
    // Cross-provider session sync
    if (FocusProvider.isAnySessionActive) {
      debugPrint(
          '[StudyRoom] Another session (${FocusProvider.globalActiveSession}) active.');
      return;
    }
    FocusProvider.claimSession('study_room');

    _isStudying = true;
    _myStudySeconds = 0;

    _studyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _myStudySeconds++;
      notifyListeners();
    });

    _addSystemMessage('$_myDisplayName started studying 📖',
        type: MessageType.studyStart);

    _updateMyMemberStatus(isStudying: true);
    notifyListeners();
  }

  void stopStudyTimer() {
    if (!_isStudying) return;

    _studyTimer?.cancel();
    _studyTimer = null;
    _isStudying = false;

    final minutes = _myStudySeconds ~/ 60;
    if (minutes > 0) {
      _addSystemMessage(
        '$_myDisplayName studied for $minutes minutes ✅',
        type: MessageType.studyEnd,
      );
    }

    _updateMyMemberStatus(
        isStudying: false, studyMinutes: _myStudySeconds ~/ 60);

    // Log to history
    if (minutes > 0) {
      try {
        HistoryService.instance.logEvent(
          'study_room',
          'Study room session',
          '${minutes}min in ${_currentRoom?.name ?? "room"}',
          duration: minutes,
          xp: 5 + minutes ~/ 5,
          gold: 1 + minutes ~/ 15,
        );
      } catch (_) {}
    }

    FocusProvider.releaseSession('study_room');
    _myStudySeconds = 0;
    notifyListeners();
  }

  void _updateMyMemberStatus({bool? isStudying, int? studyMinutes}) {
    if (_currentRoom == null) return;

    final room = _currentRoom!;
    final updatedMembers = room.members.map((m) {
      if (m.id == myUserId) {
        return m.copyWith(
          isStudying: isStudying ?? m.isStudying,
          studyMinutes: studyMinutes ?? m.studyMinutes,
          isOnline: true,
        );
      }
      return m;
    }).toList();

    final updatedRoom = room.copyWith(members: updatedMembers);
    _roomHubByCode[room.roomCode] = updatedRoom;
    _currentRoom = updatedRoom;
  }

  void _addSystemMessage(String text, {MessageType type = MessageType.system}) {
    final roomId = _currentRoom?.id;
    if (roomId == null) return;

    final roomMessages = _roomMessagesByRoomId[roomId] ?? [];
    roomMessages.add(RoomMessage(
      id: _uuid.v4(),
      roomId: roomId,
      senderId: 'system',
      senderName: 'System',
      text: text,
      timestamp: DateTime.now(),
      type: type,
    ));

    _roomMessagesByRoomId[roomId] = roomMessages;
    _messages = roomMessages;
  }

  void _addCommunitySystemMessage(String communityCode, String text) {
    final roomMessages = _communityMessagesByCode[communityCode] ?? [];
    roomMessages.add(RoomMessage(
      id: _uuid.v4(),
      roomId: communityCode,
      senderId: 'system',
      senderName: 'System',
      text: text,
      timestamp: DateTime.now(),
      type: MessageType.system,
    ));
    _communityMessagesByCode[communityCode] = roomMessages;
    if (_joinedCommunity?.code == communityCode) {
      _communityMessages = roomMessages;
    }
  }

  String _generateUniqueRoomCode() {
    String code = StudyRoom.generateRoomCode();
    while (_roomHubByCode.containsKey(code)) {
      code = StudyRoom.generateRoomCode();
    }
    return code;
  }

  String _generateUniqueCommunityCode() {
    String code = StudyCommunity.generateCommunityCode();
    while (_communityHubByCode.containsKey(code)) {
      code = StudyCommunity.generateCommunityCode();
    }
    return code;
  }

  // ── Notice Management ──

  void addNotice({required String title, required String body}) {
    if (_joinedCommunity == null) return;
    final code = _joinedCommunity!.code;
    final notice = CommunityNotice(
      id: _uuid.v4(),
      communityCode: code,
      authorId: myUserId,
      authorName: _myDisplayName,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    );
    _noticesByCommunity.putIfAbsent(code, () => []);
    _noticesByCommunity[code]!.add(notice);
    _addCommunitySystemMessage(code, '📢 New notice: $title');
    notifyListeners();
  }

  void deleteNotice(String noticeId) {
    if (_joinedCommunity == null) return;
    final code = _joinedCommunity!.code;
    final list = _noticesByCommunity[code];
    if (list == null) return;
    list.removeWhere((n) => n.id == noticeId);
    notifyListeners();
  }

  void togglePinNotice(String noticeId) {
    if (_joinedCommunity == null) return;
    final code = _joinedCommunity!.code;
    final list = _noticesByCommunity[code];
    if (list == null) return;
    final idx = list.indexWhere((n) => n.id == noticeId);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(pinned: !list[idx].pinned);
    notifyListeners();
  }

  // ── Leave Community ──

  void leaveCommunity() {
    if (_joinedCommunity == null) return;
    final code = _joinedCommunity!.code;
    final community = _communityHubByCode[code];
    if (community != null) {
      final updatedMembers =
          community.members.where((m) => m.id != myUserId).toList();
      _communityHubByCode[code] = community.copyWith(members: updatedMembers);
      _addCommunitySystemMessage(code, '$_myDisplayName left the community');
    }
    _joinedCommunity = null;
    _communityMessages = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _studyTimer?.cancel();
    super.dispose();
  }
}
