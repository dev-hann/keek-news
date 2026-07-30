class CommunitySettings {
  const CommunitySettings();

  static const CommunitySettings defaults = CommunitySettings();

  CommunitySettings copyWith() => const CommunitySettings();
}

class CommunitySettingsNotifier extends CommunitySettings {
  const CommunitySettingsNotifier() : super();
}
