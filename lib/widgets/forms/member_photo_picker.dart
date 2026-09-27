import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/trust_repository.dart' show RepositoryException;
import '../../state/agent_providers.dart';
import '../app_dialog.dart';
import '../inputs.dart';
import 'photo_crop_dialog.dart';

/// A photo on the office and agent member forms: the member's own, their
/// Aadhaar card, or their Vaarisdar's. A picked image is first framed in
/// [showPhotoCropDialog], then goes to Cloudinary, and only its `https://`
/// URL is kept on the member, as every other file is: the database holds text
/// only.
///
/// Records saved before Cloudinary held the image itself as a `data:` URL;
/// those still show, and are replaced by a Cloudinary URL the next time a
/// photo is picked or adjusted.
class MemberPhotoPicker extends ConsumerStatefulWidget {
  const MemberPhotoPicker({
    super.key,
    required this.url,
    required this.onChanged,
    this.label = 'Member Photo',
    this.shapes = const [CropShape.square],
  });

  final String url;
  final ValueChanged<String> onChanged;
  final String label;

  /// Frames offered when cropping; the first is the default.
  final List<CropShape> shapes;

  @override
  ConsumerState<MemberPhotoPicker> createState() => _MemberPhotoPickerState();
}

class _MemberPhotoPickerState extends ConsumerState<MemberPhotoPicker> {
  bool _busy = false;

  /// The photo as picked, before cropping, so Adjust starts from all of it
  /// rather than from the part already cut out. Only kept while the form is
  /// open.
  Uint8List? _original;
  String _originalName = 'photo';

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final dot = file.name.lastIndexOf('.');
    final name = dot > 0 ? file.name.substring(0, dot) : file.name;
    await _run(() async {
      final bytes = await file.readAsBytes();
      if (await _cropAndUpload(bytes, name)) {
        _original = bytes;
        _originalName = name;
      }
    });
  }

  Future<void> _adjust() => _run(() async {
        await _cropAndUpload(_original ?? await _download(), _originalName);
      });

  /// Returns false if the user cancelled the crop.
  Future<bool> _cropAndUpload(Uint8List bytes, String name) async {
    final cropped = await showPhotoCropDialog(
      context,
      bytes: bytes,
      shapes: widget.shapes,
    );
    if (cropped == null) return false;
    final url = await ref
        .read(certificateUploaderProvider)
        .upload(cropped, '$name.jpg');
    widget.onChanged(url);
    return true;
  }

  /// The saved photo, for adjusting one that was picked in an earlier visit.
  Future<Uint8List> _download() async {
    final url = widget.url;
    if (url.startsWith('data:')) return base64Decode(url.split(',').last);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {
      // Reported below.
    }
    throw const RepositoryException(
      'Could not open the saved photo. Choose it again instead.',
    );
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() => _busy = true);
    try {
      await work();
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          e is RepositoryException ? e.message : 'Could not add the photo.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _image(String url) {
    Widget broken(BuildContext _, Object _, StackTrace? _) =>
        const Center(child: Icon(Icons.broken_image_outlined));
    // Contain, not cover: the box shows exactly what was cropped.
    if (url.startsWith('data:')) {
      return Image.memory(
        base64Decode(url.split(',').last),
        fit: BoxFit.contain,
        errorBuilder: broken,
      );
    }
    return Image.network(url, fit: BoxFit.contain, errorBuilder: broken);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasPhoto = widget.url.isNotEmpty;
    final linkStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label),
        const SizedBox(height: 8),
        InkWell(
          onTap: _busy ? null : _pick,
          borderRadius: BorderRadius.circular(Radii.panel),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: hasPhoto ? c.brand.withValues(alpha: 0.5) : c.border,
              ),
              borderRadius: BorderRadius.circular(Radii.panel),
              color: c.surfaceMuted,
            ),
            clipBehavior: Clip.antiAlias,
            child: _busy
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : hasPhoto
                    ? _image(widget.url)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, color: c.textMuted, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add photo',
                            style: TextStyle(color: c.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
          ),
        ),
        if (hasPhoto && !_busy)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _adjust,
                style: linkStyle,
                icon: const Icon(Icons.crop_rotate, size: 16),
                label: const Text('Adjust'),
              ),
              TextButton(
                onPressed: () {
                  _original = null;
                  widget.onChanged('');
                },
                style: linkStyle,
                child: Text('Remove', style: TextStyle(color: c.danger)),
              ),
            ],
          ),
      ],
    );
  }
}
