import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rudransh_ct/widgets/forms/member_photo_picker.dart';

/// A 1×1 PNG, the way photos were stored before they moved to Cloudinary.
const _legacyPhoto =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<List<String>> _pump(WidgetTester tester, String url) async {
  final changes = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: MemberPhotoPicker(url: url, onChanged: changes.add),
        ),
      ),
    ),
  );
  await tester.pump();
  return changes;
}

void main() {
  testWidgets('with no photo it asks for one', (tester) async {
    await _pump(tester, '');
    expect(find.text('Tap to add photo'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('a photo saved the old way still shows', (tester) async {
    await _pump(tester, _legacyPhoto);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Remove clears the photo', (tester) async {
    final changes = await _pump(
      tester,
      'https://res.cloudinary.com/demo/image/upload/p.jpg',
    );
    await tester.tap(find.text('Remove'));
    expect(changes, ['']);
  });
}
