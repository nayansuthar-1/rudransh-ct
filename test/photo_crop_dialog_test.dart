import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rudransh_ct/widgets/app_dialog.dart';
import 'package:rudransh_ct/widgets/forms/photo_crop_dialog.dart';

/// 200 × 100: the left half red, the right half blue.
Future<ui.Image> _halves() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = const Color(0xFFFF0000))
    ..drawRect(const Rect.fromLTWH(100, 0, 100, 100), Paint()..color = const Color(0xFF0000FF));
  return recorder.endRecording().toImage(200, 100);
}

/// Opens the dialog, lets [adjust] work it, taps Use photo and returns the
/// decoded result.
Future<img.Image> _crop(
  WidgetTester tester, {
  List<CropShape> shapes = const [CropShape.square],
  Future<void> Function()? adjust,
}) async {
  final image = (await tester.runAsync(_halves))!;
  Uint8List? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await AppDialog.show<Uint8List>(
                context: context,
                builder: (_) => PhotoCropDialog(image: image, shapes: shapes),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (adjust != null) await adjust();

  await tester.tap(find.text('Use photo'));
  // Drawing and encoding are real async work, outside the fake clock.
  await tester.runAsync(() async {
    for (var i = 0; i < 50 && result == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pumpAndSettle();
  expect(result, isNotNull);
  return img.decodeJpg(result!)!;
}

bool _reddish(img.Pixel p) => p.r > 200 && p.b < 60;
bool _bluish(img.Pixel p) => p.b > 200 && p.r < 60;

void main() {
  testWidgets('a square crop takes the middle of the photo', (tester) async {
    final out = await _crop(tester);
    expect([out.width, out.height], [100, 100]);
    expect(_reddish(out.getPixel(10, 50)), isTrue);
    expect(_bluish(out.getPixel(90, 50)), isTrue);
  });

  testWidgets('rotating right turns the left side to the top', (tester) async {
    final out = await _crop(
      tester,
      adjust: () async {
        await tester.tap(find.byTooltip('Rotate right'));
        await tester.pump();
      },
    );
    expect([out.width, out.height], [100, 100]);
    expect(_reddish(out.getPixel(50, 10)), isTrue);
    expect(_bluish(out.getPixel(50, 90)), isTrue);
  });

  testWidgets('dragging the photo right shows more of its left side',
      (tester) async {
    final out = await _crop(
      tester,
      adjust: () async {
        final photo = find.byWidgetPredicate(
          (w) => w is CustomPaint && '${w.painter.runtimeType}' == '_CropPainter',
        );
        await tester.drag(photo, const Offset(400, 0));
        await tester.pump();
      },
    );
    // Dragged as far as it goes: the frame sits on the red half.
    expect(_reddish(out.getPixel(90, 50)), isTrue);
  });

  testWidgets('the Aadhaar card frame and the whole photo', (tester) async {
    final card = await _crop(
      tester,
      shapes: const [CropShape.card, CropShape.whole],
    );
    expect([card.width, card.height], [159, 100]);

    final whole = await _crop(
      tester,
      shapes: const [CropShape.card, CropShape.whole],
      adjust: () async {
        await tester.tap(find.text('Whole photo'));
        await tester.pump();
      },
    );
    expect([whole.width, whole.height], [200, 100]);
  });

  testWidgets('Cancel gives nothing back', (tester) async {
    final image = (await tester.runAsync(_halves))!;
    Uint8List? result = Uint8List(1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await AppDialog.show<Uint8List>(
                  context: context,
                  builder: (_) => PhotoCropDialog(image: image),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
