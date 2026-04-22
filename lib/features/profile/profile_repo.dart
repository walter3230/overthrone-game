import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:overthrone/features/heroes/heroes_page.dart' show GameHero;
import 'dart:typed_data' show Uint8List;
import 'dart:convert' show base64Encode, base64Decode;

class ProfileRepo {
  ProfileRepo._();
  static final ProfileRepo I = ProfileRepo._();

  /// ===================== ROSTER (PvE Sim için) ==============================
  /// Not: Burada kalıcı depolama zorunlu değil; kahraman tanımların uygulama
  /// içinde zaten mevcut. App açılışında bir kez setRoster(allHeroes) çağır.
  final ValueNotifier<List<GameHero>> _rosterVN = ValueNotifier<List<GameHero>>(
    <GameHero>[],
  );

  /// PvE Sim ve diğer ekranların kullanacağı getter
  List<GameHero> get heroes => _rosterVN.value;

  /// Uygulama açılışında 1 kez çağır: ProfileRepo.I.setRoster(allHeroes);
  void setRoster(List<GameHero> list) {
    _rosterVN.value = List<GameHero>.unmodifiable(list);
  }

  /// Yardımcılar (opsiyonel)
  GameHero? heroByName(String name) {
    for (final h in _rosterVN.value) {
      if (h.name == name) return h;
    }
    return null;
  }

  void addHero(GameHero h) {
    _rosterVN.value = List<GameHero>.unmodifiable([..._rosterVN.value, h]);
  }

  void removeHeroByName(String name) {
    _rosterVN.value = List<GameHero>.unmodifiable(
      _rosterVN.value.where((h) => h.name != name),
    );
  }

  /// ==========================================================================

  /// UI'nin dinleyeceği ham fotoğraf baytları (yoksa null = renkli avatar)
  final ValueNotifier<Uint8List?> avatarBytes = ValueNotifier<Uint8List?>(null);

  static const _kName = 'profile_name';
  static const _kAvatarColorIdx = 'profile_avatar_idx';
  static const _kAvatarPath = 'profile_avatar_path';
  static const _kAvatarB64 = 'profile.avatar.b64';
  static const _kPid = 'profile_player_id';
  static const _kAvatarFrame = 'profile_avatar_frame';

  /// UI’nin dinleyeceği alanlar
  final ValueNotifier<String> name = ValueNotifier<String>('Player_123');
  final ValueNotifier<int> avatarColorIndex = ValueNotifier<int>(0);

  /// İstersen renk/ikon index’i için
  final ValueNotifier<int> avatarIndex = ValueNotifier<int>(0);

  /// Seçilmiş fotoğraf yolunu yayınlar (yoksa null)
  final ValueNotifier<String?> avatarImagePath = ValueNotifier<String?>(null);
  final ValueNotifier<int> avatarFrame = ValueNotifier<int>(0); // 0=kapalı

  String playerId = 'P-000000';

  Future<void> load() async {
    final pfs = await SharedPreferences.getInstance();

    name.value = pfs.getString(_kName) ?? 'Player_123';
    avatarColorIndex.value = pfs.getInt(_kAvatarColorIdx) ?? 0;
    avatarImagePath.value = pfs.getString(_kAvatarPath);
    avatarFrame.value = pfs.getInt(_kAvatarFrame) ?? 0;

    playerId = pfs.getString(_kPid) ?? _genId();
    await pfs.setString(_kPid, playerId);

    // Fotoğrafı yükle: önce base64, yoksa path'ten dene
    final s = pfs.getString(_kAvatarB64);
    if (s != null && s.isNotEmpty) {
      try {
        avatarBytes.value = base64Decode(s);
      } catch (_) {
        avatarBytes.value = null;
      }
    } else if (avatarImagePath.value != null) {
      try {
        final f = File(avatarImagePath.value!);
        if (await f.exists()) {
          avatarBytes.value = await f.readAsBytes();
        }
      } catch (_) {
        avatarBytes.value = null;
      }
    }
  }

  Future<void> setName(String v) async {
    final pfs = await SharedPreferences.getInstance();
    name.value = v;
    await pfs.setString(_kName, v);
  }

  Future<void> setAvatarColor(int idx) async {
    final pfs = await SharedPreferences.getInstance();
    avatarColorIndex.value = idx;
    await pfs.setInt(_kAvatarColorIdx, idx);
  }

  /// Fotoğrafı doğrudan bayt olarak kaydet (örn. crop sonrası)
  Future<void> setAvatarBytes(Uint8List bytes) async {
    avatarBytes.value = bytes;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAvatarB64, base64Encode(bytes));
  }

  Future<void> setAvatarFrame(int idx) async {
    final pfs = await SharedPreferences.getInstance();
    avatarFrame.value = idx;
    await pfs.setInt(_kAvatarFrame, idx);
  }

  /// Galeriden seçilen görseli uygulama dizinine kopyalar, yolu ve baytları kaydeder.
  Future<void> setAvatarFromGallery(XFile picked) async {
    final dir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory(p.join(dir.path, 'avatars'));
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }

    final ext = p.extension(picked.path).toLowerCase();
    final fileName =
        'avatar_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}';
    final targetPath = p.join(avatarsDir.path, fileName);

    // Dosyayı kopyala
    final saved = await File(picked.path).copy(targetPath);

    final pfs = await SharedPreferences.getInstance();

    // Eski foto varsa silelim (temizlik)
    final old = avatarImagePath.value;
    if (old != null && old != saved.path) {
      try {
        await File(old).delete();
      } catch (_) {}
    }

    // Yol + bayt + base64 kaydı
    avatarImagePath.value = saved.path;
    await pfs.setString(_kAvatarPath, saved.path);

    try {
      final bytes = await saved.readAsBytes();
      avatarBytes.value = bytes;
      await pfs.setString(_kAvatarB64, base64Encode(bytes));
    } catch (_) {
      // okunamazsa sadece yol kalsın, UI renkli avatara düşer
      avatarBytes.value = null;
      await pfs.remove(_kAvatarB64);
    }
  }

  /// Fotoğrafı kaldır (renkli avatarı kullan)
  Future<void> clearAvatarImage() async {
    final pfs = await SharedPreferences.getInstance();

    final old = avatarImagePath.value;
    avatarImagePath.value = null;
    avatarBytes.value = null;

    await pfs.remove(_kAvatarPath);
    await pfs.remove(_kAvatarB64);

    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
  }

  String _genId() {
    final r = math.Random();
    return 'P-${100000 + r.nextInt(900000)}';
  }
}
