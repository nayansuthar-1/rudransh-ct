import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/trust_repository.dart' show RepositoryException;
import '../app_dialog.dart';

/// The shape a photo is cut to in [showPhotoCropDialog].
class CropShape {
  const CropShape(this.label, this.ratio);

  final String label;

  /// Width over height. Null keeps the photo's own shape.
  final double? ratio;

  /// Member and Vaarisdar photos: the certificate prints a square.
  static const square = CropShape('Square', 1);

  /// An Aadhaar card is ID-1 size, 85.6 × 54 mm.
  static const card = CropShape('Card', 85.6 / 54);

  static const whole = CropShape('Whole photo', null);
}

/// Lets the user move, zoom and rotate a photo inside a frame, and returns
/// the framed part as a JPEG, or null if they cancel.
///
/// Throws [RepositoryException] when [bytes] is not an image the browser can
/// open.
Future<Uint8List?> showPhotoCropDialog(
  BuildContext context, {
  required Uint8List bytes,
  List<CropShape> shapes = const [CropShape.square],
}) async {
  final ui.Image image;
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    image = (await codec.getNextFrame()).image;
    codec.dispose();
  } catch (_) {
    throw const RepositoryException(
      'This photo could not be opened. Choose a JPG or PNG.',
    );
  }
  if (!context.mounted) {
    image.dispose();
    return null;
  }
  // The dialog owns [image] from here and disposes it when it closes.
  return AppDialog.show<Uint8List>(
    context: context,
    builder: (_) => PhotoCropDialog(image: image, shapes: shapes),
  );
}

class PhotoCropDialog extends StatefulWidget {
  const PhotoCropDialog({
    super.key,
    required this.image,
    this.shapes = const [CropShape.square],
  });

  final ui.Image image;
  final List<CropShape> shapes;

  @override
  State<PhotoCropDialog> createState() => _PhotoCropDialogState();
}

class _PhotoCropDialogState extends State<PhotoCropDialog> {
  static const _maxZoom = 5.0;

  /// Longest side of the saved photo, in pixels. Enough to read an Aadhaar
  /// card and to print the certificate, and keeps uploads small.
  static const _maxSide = 1400;

  /// Quarter turns clockwise.
  int _turns = 0;

  /// 1 means the frame takes in as much of the photo as it can.
  double _zoom = 1;

  /// How far the photo's centre sits from the frame's centre, in photo
  /// pixels (after rotation).
  Offset _offset = Offset.zero;

  int _shape = 0;
  double _zoomAtStart = 1;
  bool _saving = false;

  @override
  void dispose() {
    widget.image.dispose();
    super.dispose();
  }

  Size get _rotated => _turns.isOdd
      ? Size(widget.image.height.toDouble(), widget.image.width.toDouble())
      : Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  double get _ratio {
    final r = _rotated;
    return widget.shapes[_shape].ratio ?? r.width / r.height;
  }

  /// The part of the photo inside the frame, in photo pixels.
  Size get _crop {
    final r = _rotated;
    final fit = _ratio > r.width / r.height
        ? Size(r.width, r.width / _ratio)
        : Size(r.height * _ratio, r.height);
    return fit / _zoom;
  }

  /// Keeps the photo covering the whole frame.
  Offset _clamp(Offset o) {
    final r = _rotated;
    final crop = _crop;
    final mx = math.max(0.0, (r.width - crop.width) / 2);
    final my = math.max(0.0, (r.height - crop.height) / 2);
    return Offset(o.dx.clamp(-mx, mx), o.dy.clamp(-my, my));
  }

  void _setZoom(double z) => setState(() {
        _zoom = z.clamp(1.0, _maxZoom);
        _offset = _clamp(_offset);
      });

  void _rotate(int by) => setState(() {
        _turns = (_turns + by) % 4;
        // Turn the offset with the photo so the same part stays in view.
        _offset = _clamp(
          by > 0
              ? Offset(-_offset.dy, _offset.dx)
              : Offset(_offset.dy, -_offset.dx),
        );
      });

  void _reset() => setState(() {
        _turns = 0;
        _zoom = 1;
        _offset = Offset.zero;
      });

  Rect _frameIn(Size area) {
    const margin = 20.0;
    final w = math.max(1.0, area.width - margin * 2);
    final h = math.max(1.0, area.height - margin * 2);
    final size = w / h > _ratio ? Size(h * _ratio, h) : Size(w, w / _ratio);
    return Rect.fromCenter(
      center: area.center(Offset.zero),
      width: size.width,
      height: size.height,
    );
  }

  Future<void> _done() async {
    setState(() => _saving = true);
    try {
      final bytes = await _render();
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(context, 'Could not cut the photo. Try again.', error: true);
    }
  }

  /// Draws the framed part the same way the editor shows it, then encodes it
  /// as a JPEG (no transparency, so the background is white).
  Future<Uint8List> _render() async {
    final crop = _crop;
    final k = math.min(1.0, _maxSide / math.max(crop.width, crop.height));
    final w = math.max(1, (crop.width * k).round());
    final h = math.max(1, (crop.height * k).round());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(Colors.white, BlendMode.src)
      ..scale(k)
      ..translate(crop.width / 2 + _offset.dx, crop.height / 2 + _offset.dy)
      ..rotate(_turns * math.pi / 2);
    canvas.drawImage(
      widget.image,
      Offset(-widget.image.width / 2, -widget.image.height / 2),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    picture.dispose();
    final data = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
    out.dispose();
    if (data == null) throw StateError('no pixels');

    return img.encodeJpg(
      img.Image.fromBytes(
        width: w,
        height: h,
        bytes: data.buffer,
        bytesOffset: data.offsetInBytes,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      ),
      quality: 85,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = MediaQuery.of(context);
    final fullScreen = context.isMobile;
    final gutter = fullScreen ? 16.0 : 24.0;

    final body = Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.fromLTRB(
            gutter,
            (fullScreen ? media.padding.top : 0) + (fullScreen ? 12 : 16),
            fullScreen ? 8 : 14,
            12,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Adjust photo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: c.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 19),
                tooltip: 'Close',
              ),
            ],
          ),
        ),

        // The photo and its frame.
        Expanded(
          child: ColoredBox(
            color: const Color(0xFF202124),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final area = constraints.biggest;
                final frame = _frameIn(area);
                final scale = frame.width / _crop.width;
                return Listener(
                  onPointerSignal: (e) {
                    if (e is PointerScrollEvent) {
                      _setZoom(_zoom * math.exp(-e.scrollDelta.dy / 400));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) => _zoomAtStart = _zoom,
                    onScaleUpdate: (d) => setState(() {
                      _zoom = (_zoomAtStart * d.scale).clamp(1.0, _maxZoom);
                      final s = frame.width / _crop.width;
                      _offset = _clamp(_offset + d.focalPointDelta / s);
                    }),
                    child: CustomPaint(
                      size: area,
                      painter: _CropPainter(
                        image: widget.image,
                        turns: _turns,
                        scale: scale,
                        offset: _offset,
                        frame: frame,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Controls
        Container(
          color: c.surface,
          padding: EdgeInsets.fromLTRB(gutter, Space.md, gutter, 0),
          child: Column(
            children: [
              if (widget.shapes.length > 1) ...[
                Wrap(
                  spacing: Space.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < widget.shapes.length; i++)
                      ChoiceChip(
                        label: Text(widget.shapes[i].label),
                        selected: i == _shape,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() {
                                  _shape = i;
                                  _zoom = 1;
                                  _offset = Offset.zero;
                                }),
                      ),
                  ],
                ),
                const SizedBox(height: Space.sm),
              ],
              Row(
                children: [
                  IconButton(
                    onPressed: _saving ? null : () => _rotate(-1),
                    icon: const Icon(Icons.rotate_left),
                    tooltip: 'Rotate left',
                  ),
                  Icon(Icons.zoom_out, size: 20, color: c.textMuted),
                  Expanded(
                    child: Slider(
                      value: _zoom,
                      min: 1,
                      max: _maxZoom,
                      onChanged: _saving ? null : _setZoom,
                    ),
                  ),
                  Icon(Icons.zoom_in, size: 20, color: c.textMuted),
                  IconButton(
                    onPressed: _saving ? null : () => _rotate(1),
                    icon: const Icon(Icons.rotate_right),
                    tooltip: 'Rotate right',
                  ),
                ],
              ),
              Text(
                'Drag to move the photo. Pinch, scroll or use the slider to zoom.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: c.textSecondary),
              ),
            ],
          ),
        ),

        // Footer
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            gutter,
            Space.md,
            gutter,
            Space.md + (fullScreen ? media.padding.bottom : 0),
          ),
          color: c.surface,
          child: Row(
            children: [
              TextButton(
                onPressed: _saving ? null : _reset,
                child: const Text('Reset'),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: Space.sm),
              FilledButton(
                onPressed: _saving ? null : _done,
                child: _saving
                    ? const ButtonSpinner()
                    : const Text('Use photo'),
              ),
            ],
          ),
        ),
      ],
    );

    if (fullScreen) {
      return SizedBox(
        width: media.size.width,
        height: media.size.height,
        child: body,
      );
    }
    return SizedBox(
      width: 600,
      height: math.min(700.0, media.size.height * 0.9),
      child: body,
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.turns,
    required this.scale,
    required this.offset,
    required this.frame,
  });

  final ui.Image image;
  final int turns;

  /// Screen pixels per photo pixel.
  final double scale;
  final Offset offset;
  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(
        frame.center.dx + offset.dx * scale,
        frame.center.dy + offset.dy * scale,
      )
      ..rotate(turns * math.pi / 2)
      ..scale(scale)
      ..drawImage(
        image,
        Offset(-image.width / 2, -image.height / 2),
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore();

    // Dim everything outside the frame.
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(frame),
      Paint()..color = const Color(0xAA000000),
    );

    // Rule-of-thirds guides, then the frame itself.
    final guide = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = frame.left + frame.width * i / 3;
      final y = frame.top + frame.height * i / 3;
      canvas
        ..drawLine(Offset(x, frame.top), Offset(x, frame.bottom), guide)
        ..drawLine(Offset(frame.left, y), Offset(frame.right, y), guide);
    }
    canvas.drawRect(
      frame,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image ||
      old.turns != turns ||
      old.scale != scale ||
      old.offset != offset ||
      old.frame != frame;
}
