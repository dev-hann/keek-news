import 'package:flutter_test/flutter_test.dart';
import 'package:keek_news/model/community.dart';
import 'package:keek_news/provider/settings_provider.dart';
import 'package:keek_news/use_case/feed_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockFeedUseCase extends Mock implements FeedUseCase {}

void main() {
  late MockFeedUseCase useCase;

  setUp(() {
    useCase = MockFeedUseCase();
  });

  setUpAll(() {
    registerFallbackValue(CommunityId.dogdrip);
  });

  SettingsNotifier makeNotifier() => SettingsNotifier(useCase);

  group('SettingsNotifier initial state', () {
    test('loads enabled communities from useCase', () {
      final initial = {CommunityId.dogdrip, CommunityId.ppomppu};
      when(() => useCase.getEnabledCommunities()).thenReturn(initial);

      final notifier = makeNotifier();

      expect(notifier.state, initial);
    });
  });

  group('SettingsNotifier toggle', () {
    test('calls useCase.toggleCommunity and refreshes state', () {
      when(
        () => useCase.getEnabledCommunities(),
      ).thenReturn({CommunityId.dogdrip, CommunityId.ppomppu});
      when(() => useCase.toggleCommunity(any())).thenAnswer((_) {});

      final notifier = makeNotifier();

      when(
        () => useCase.getEnabledCommunities(),
      ).thenReturn({CommunityId.ppomppu});

      notifier.toggle(CommunityId.dogdrip);

      verify(() => useCase.toggleCommunity(CommunityId.dogdrip)).called(1);
      expect(notifier.state, {CommunityId.ppomppu});
    });
  });

  group('SettingsNotifier canDisable', () {
    test('delegates to useCase.canDisableCommunity', () {
      when(
        () => useCase.getEnabledCommunities(),
      ).thenReturn(CommunityId.values.toSet());
      when(() => useCase.canDisableCommunity(any())).thenReturn(true);

      final notifier = makeNotifier();

      expect(notifier.canDisable(CommunityId.dogdrip), isTrue);
      verify(() => useCase.canDisableCommunity(CommunityId.dogdrip)).called(1);
    });

    test('returns false when useCase says so', () {
      when(
        () => useCase.getEnabledCommunities(),
      ).thenReturn({CommunityId.dogdrip});
      when(() => useCase.canDisableCommunity(any())).thenReturn(false);

      final notifier = makeNotifier();

      expect(notifier.canDisable(CommunityId.dogdrip), isFalse);
    });
  });
}
