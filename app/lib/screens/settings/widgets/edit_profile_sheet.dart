/// EditProfileSheet — bottom sheet for editing display name and username,
/// and uploading a profile photo from camera or gallery.
library edit_profile_sheet;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:instructor/providers/auth_providers.dart' show currentUserProvider;
import 'package:instructor/services/auth_service.dart'
    show AuthException, authServiceProvider;

/// Shows a modal bottom sheet that lets the user update their profile.
Future<void> showEditProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => const _EditProfileSheet(),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;

  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  // Locally picked image bytes to preview before upload completes.
  Uint8List? _pendingImageBytes;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _usernameCtrl = TextEditingController(text: user?.username ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  // ── Photo picker ─────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    // Let any dismissing sheet animation finish before opening camera/gallery.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _pendingImageBytes = bytes;
        _uploadingPhoto = true;
        _error = null;
      });

      try {
        await ref.read(authServiceProvider).uploadProfilePhoto(
              bytes: bytes,
              mimeType: picked.mimeType ?? 'image/jpeg',
            );
      } on AuthException catch (e) {
        if (mounted) setState(() => _error = e.userMessage);
      } catch (_) {
        if (mounted) setState(() => _error = 'Photo upload failed. Please try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open picker. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showSourcePicker() {
    // Return the chosen ImageSource as the sheet result so it closes cleanly
    // before _pickPhoto tries to open the camera/gallery.
    showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo Library'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    ).then((source) {
      if (source != null) _pickPhoto(source);
    });
  }

  // ── Save profile fields ───────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();

    try {
      await ref.read(authServiceProvider).updateProfile(
            name: name.isEmpty ? null : name,
            username: username.isEmpty ? null : username,
          );
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final insets = MediaQuery.viewInsetsOf(context);
    final currentUser = ref.watch(currentUserProvider);

    // Show local preview while uploading; fall back to cached photoUrl.
    final photoUrl = currentUser?.photoUrl;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Title ──────────────────────────────────────────────────────
          Row(
            children: [
              Text('Edit Profile', style: theme.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Avatar picker ──────────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: _uploadingPhoto ? null : _showSourcePicker,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: _pendingImageBytes != null
                        ? MemoryImage(_pendingImageBytes!)
                        : (photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl) as ImageProvider
                            : null),
                    child: (_pendingImageBytes == null &&
                            (photoUrl == null || photoUrl.isEmpty))
                        ? Text(
                            (currentUser?.name?.isNotEmpty == true
                                    ? currentUser!.name![0]
                                    : currentUser?.email?.isNotEmpty == true
                                        ? currentUser!.email[0]
                                        : '?')
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 32,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  // Upload progress overlay
                  if (_uploadingPhoto)
                    const Positioned.fill(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.black45,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  // Camera badge
                  Material(
                    color: colorScheme.secondaryContainer,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Name ───────────────────────────────────────────────────────
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'e.g. Alex',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
          ),

          const SizedBox(height: 16),

          // ── Username ───────────────────────────────────────────────────
          TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'e.g. alex_meditates',
              helperText: 'Letters, numbers, and underscores only',
              border: OutlineInputBorder(),
            ),
            maxLength: 30,
          ),

          // ── Error ──────────────────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: colorScheme.error, fontSize: 13),
            ),
          ],

          const SizedBox(height: 20),

          // ── Save button ────────────────────────────────────────────────
          FilledButton(
            onPressed: (_saving || _uploadingPhoto) ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

