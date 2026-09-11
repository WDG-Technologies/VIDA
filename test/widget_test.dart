import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/data/daily_verse.dart';
import 'package:vida_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('daily verses JSON loads full list (not placeholder)', () async {
    final all = await DailyVerseService.loadAll();
    expect(all.length, greaterThan(100));
    expect(all.first.referencia, isNotEmpty);
    expect(all.first.versiculo, isNotEmpty);
    final today = await DailyVerseService.forToday();
    expect(today.referencia, isNotEmpty);
  });

  testWidgets('VidaApp renders splash when no name stored', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const VidaApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('VIDA'), findsWidgets);
    expect(find.text('Personaliza tu experiencia'), findsOneWidget);
  });

  testWidgets('VidaApp renders home when name is stored', (tester) async {
    SharedPreferences.setMockInitialValues({'user_name': 'Test'});
    await tester.pumpWidget(const VidaApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Test'), findsWidgets);
    expect(find.text('VIDA'), findsWidgets);
  });
}
