import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/service/service_locator.dart';
import 'package:keek_news/use_case/feed_use_case.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Set<CommunityId>>(
      (ref) => SettingsNotifier(sl<FeedUseCase>()),
    );

class SettingsNotifier extends StateNotifier<Set<CommunityId>> {
  SettingsNotifier(this._useCase) : super(_useCase.getEnabledCommunities());

  final FeedUseCase _useCase;

  void toggle(CommunityId id) {
    _useCase.toggleCommunity(id);
    state = _useCase.getEnabledCommunities();
  }

  bool canDisable(CommunityId id) => _useCase.canDisableCommunity(id);
}
