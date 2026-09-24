import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/trust_repository.dart' show RepositoryException;
import '../../state/agent_providers.dart';
import '../app_dialog.dart';
import '../inputs.dart';

/// The member's photo on the office and agent forms. The picked image goes to
/// Cloudinary and only its `https://` URL is kept on the member, as every
/// other file is: the database holds text only.
///
/// Records saved before this held the image itself as a `data:` URL; those
/// still show, and are replaced by a Cloudinary URL the next time a photo is
/// picked.
class MemberPhotoPicker extends ConsumerStatefulWidget {
  const MemberPhotoPicker({
    super.key,
    required this.url,
    required this.onChanged,
  });

  final String url;
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<MemberPhotoPicker> createState() => _MemberPhotoPickerState();
}

class _MemberPhotoPickerState extends ConsumerState<MemberPhotoPicker> {
  bool _uploading = false;

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final url =
          await ref.read(certificateUploaderProvider).upload(bytes, file.name);
      widget.onChanged(url);
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          e is RepositoryException ? e.message : 'Could not add the photo.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _image(String url) {
    Widget broken(BuildContext _, Object _, StackTrace? _) =>
        const Center(child: Icon(Icons.broken_image_outlined));
    if (url.startsWith('data:')) {
      return Image.memory(
        base64Decode(url.split(',').last),
        fit: BoxFit.cover,
        errorBuilder: broken,
      );
    }
    return Image.network(url, fit: BoxFit.cover, errorBuilder: broken);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasPhoto = widget.url.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Member Photo'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _uploading ? null : _pick,
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
            child: _uploading
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
        if (hasPhoto && !_uploading)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => widget.onChanged(''),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Remove', style: TextStyle(color: c.danger)),
            ),
          ),
      ],
    );
  }
}
