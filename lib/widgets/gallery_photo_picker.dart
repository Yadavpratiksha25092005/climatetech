import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/dark_palette.dart';
import '../services/cloudinary_service.dart';

/// Gallery-backed photo picker: pick from the device gallery, upload to
/// Cloudinary, and report back the resulting secure URLs. Drop-in
/// replacement for the old UrlListInput — same `List<String> urls` +
/// `onChanged` contract — except every "add" now uploads a real photo
/// instead of pasting a URL by hand.
class GalleryPhotoPicker extends ConsumerStatefulWidget {
  final List<String> urls;
  final ValueChanged<List<String>> onChanged;

  const GalleryPhotoPicker(
      {super.key, required this.urls, required this.onChanged});

  @override
  ConsumerState<GalleryPhotoPicker> createState() => _GalleryPhotoPickerState();
}

class _GalleryPhotoPickerState extends ConsumerState<GalleryPhotoPicker> {
  final _picker = ImagePicker();
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;

    XFile? picked;
    try {
      picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
    } catch (e) {
      _showError('Could not open the gallery.');
      return;
    }
    if (picked == null) return; // user cancelled — existing photos untouched
    if (!mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(cloudinaryServiceProvider)
          .uploadImage(File(picked.path));
      // Append to the latest widget.urls, not a stale local copy — the list
      // could have changed (e.g. a removal) while the upload was in flight.
      widget.onChanged([...widget.urls, url]);
    } catch (e) {
      // Never mutate widget.urls here — a failed upload must leave every
      // already-added photo exactly as it was.
      _showError(
          e is CloudinaryException ? e.message : 'Could not upload photo.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _remove(int index) {
    final updated = [...widget.urls]..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...List.generate(
            widget.urls.length, (i) => _photoTile(widget.urls[i], i)),
        _addTile(),
      ],
    );
  }

  Widget _photoTile(String url, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 84,
              height: 84,
              color: Colors.white.withOpacity(0.06),
              child: const Icon(Icons.broken_image_outlined,
                  color: DarkPalette.textMuted),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _remove(index),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                  color: Color(0xFFE0605A), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _uploading ? null : _pickAndUpload,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: DarkPalette.leafGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DarkPalette.leafGreen.withOpacity(0.3)),
        ),
        child: _uploading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: DarkPalette.leafGreen),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: DarkPalette.leafGreen, size: 22),
                  SizedBox(height: 4),
                  Text(
                    'Add Photo',
                    style: TextStyle(
                        color: DarkPalette.leafGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}
