import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_news/domain/entities/community.dart';
import 'package:happy_news/presentation/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommunitySettings {
  const CommunitySettings({
    this.enabled = const {
      CommunityId.humoruniv,
      CommunityId.todayhumor,
      CommunityId.ppomppu,
      CommunityId.dogdrip,
    },
    this.maxRatio = 0.4,
  });

  final Set<CommunityId> enabled;
  final double maxRatio;

  bool isEnabled(CommunityId id) => enabled.contains(id);

  CommunitySettings copyWith({Set<CommunityId>? enabled, double? maxRatio}) {
    return CommunitySettings(
      enabled: enabled ?? this.enabled,
      maxRatio: maxRatio ?? this.maxRatio,
    );
  }
}

class CommunitySettingsNotifier extends Notifier<CommunitySettings> {
  late SharedPreferences _prefs;

  static const _keyEnabledPrefix = 'community_enabled_';
  static const _keyMaxRatio = 'community_max_ratio';

  @override
  CommunitySettings build() {
    _prefs = ref.read(sharedPreferencesProvider);
    final enabled = <CommunityId>{};
    for (final id in CommunityId.values) {
      final key = '$_keyEnabledPrefix${id.name}';
      final val = _prefs.getBool(key);
      if (val == null || val) {
        enabled.add(id);
      }
    }
    final maxRatio = _prefs.getDouble(_keyMaxRatio) ?? 0.4;
    return CommunitySettings(enabled: enabled, maxRatio: maxRatio);
  }

  void toggle(CommunityId id) {
    final newEnabled = Set<CommunityId>.from(state.enabled);
    if (newEnabled.contains(id)) {
      newEnabled.remove(id);
    } else {
      newEnabled.add(id);
    }
    _prefs.setBool('$_keyEnabledPrefix${id.name}', newEnabled.contains(id));
    state = state.copyWith(enabled: newEnabled);
  }

  void setMaxRatio(double ratio) {
    _prefs.setDouble(_keyMaxRatio, ratio);
    state = state.copyWith(maxRatio: ratio);
  }
}

final communitySettingsProvider =
    NotifierProvider<CommunitySettingsNotifier, CommunitySettings>(
      CommunitySettingsNotifier.new,
    );
