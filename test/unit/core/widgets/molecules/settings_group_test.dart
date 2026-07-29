import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_news/core/widgets/molecules/settings_group.dart';
import 'package:happy_news/core/widgets/molecules/settings_tile.dart';

void main() {
  group('SettingsGroup', () {
    testWidgets('should display title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsGroup(title: '화면 설정', children: [SizedBox()]),
          ),
        ),
      );

      expect(find.text('화면 설정'), findsOneWidget);
    });

    testWidgets('should display children', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsGroup(
              title: '테스트',
              children: [
                SettingsTile(title: '항목 1'),
                SettingsTile(title: '항목 2'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('항목 1'), findsOneWidget);
      expect(find.text('항목 2'), findsOneWidget);
    });
  });

  group('SettingsTile', () {
    testWidgets('should display title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SettingsTile(title: '다크 모드')),
        ),
      );

      expect(find.text('다크 모드'), findsOneWidget);
    });

    testWidgets('should display leading icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsTile(title: '다크 모드', leading: Icon(Icons.dark_mode)),
          ),
        ),
      );

      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('should display trailing switch and handle tap', (
      tester,
    ) async {
      var switchValue = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsTile(
              title: '성인 콘텐츠',
              trailing: Switch(
                value: switchValue,
                onChanged: (v) => switchValue = v,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsTile(title: '읽은 기록', onTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('읽은 기록'));
      expect(tapped, true);
    });

    testWidgets('should display subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsTile(title: '버전', subtitle: 'v1.0.0'),
          ),
        ),
      );

      expect(find.text('v1.0.0'), findsOneWidget);
    });
  });
}
