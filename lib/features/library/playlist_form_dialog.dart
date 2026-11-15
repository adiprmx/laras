/// Dialog buat/ubah playlist: nama (wajib, maks 100 karakter) +
/// deskripsi (opsional, maks 500 karakter).
///
/// Validasi tampil di bawah kolom (bukan SnackBar yang hilang): nama
/// kosong, nama terlalu panjang, deskripsi terlalu panjang.
library;

import 'package:flutter/material.dart';
import 'package:laras/data/database.dart';
import 'package:laras/l10n/generated/app_localizations.dart';

/// Hasil dialog: nama + deskripsi (null bila deskripsi dikosongkan).
class PlaylistFormResult {
  const PlaylistFormResult({required this.name, this.description});

  final String name;
  final String? description;
}

/// Tampilkan dialog. [initialName]/[initialDescription] untuk mode ubah
/// (null berarti mode buat baru). Mengembalikan null bila dibatalkan.
Future<PlaylistFormResult?> showPlaylistFormDialog(
  BuildContext context, {
  String? initialName,
  String? initialDescription,
  required bool isEditing,
}) {
  return showDialog<PlaylistFormResult>(
    context: context,
    builder: (BuildContext context) {
      return _PlaylistFormDialog(
        initialName: initialName,
        initialDescription: initialDescription,
        isEditing: isEditing,
      );
    },
  );
}

class _PlaylistFormDialog extends StatefulWidget {
  const _PlaylistFormDialog({
    this.initialName,
    this.initialDescription,
    required this.isEditing,
  });

  final String? initialName;
  final String? initialDescription;
  final bool isEditing;

  @override
  State<_PlaylistFormDialog> createState() => _PlaylistFormDialogState();
}

class _PlaylistFormDialogState extends State<_PlaylistFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _nameError;
  String? _descriptionError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final String name = _nameController.text.trim();
    final String description = _descriptionController.text.trim();
    String? nameError;
    if (name.isEmpty) {
      nameError = strings.playlistNameEmpty;
    } else if (name.length > kMaxPlaylistNameLength) {
      nameError = strings.playlistNameTooLong;
    }
    final String? descriptionError =
        description.length > kMaxPlaylistDescriptionLength
        ? strings.playlistDescriptionTooLong
        : null;
    setState(() {
      _nameError = nameError;
      _descriptionError = descriptionError;
    });
    if (nameError != null || descriptionError != null) return;
    Navigator.of(context).pop(
      PlaylistFormResult(
        name: name,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.isEditing ? strings.renamePlaylist : strings.createPlaylist,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLength: kMaxPlaylistNameLength,
              decoration: InputDecoration(
                labelText: strings.playlistNameLabel,
                hintText: strings.playlistNameHint,
                errorText: _nameError,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: kMaxPlaylistDescriptionLength,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                labelText: strings.playlistDescriptionLabel,
                hintText: strings.playlistDescriptionHint,
                errorText: _descriptionError,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(strings.save)),
      ],
    );
  }
}
