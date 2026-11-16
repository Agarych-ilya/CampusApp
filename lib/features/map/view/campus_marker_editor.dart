import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/campus_map_api.dart';

/// The dialog itself owns its controllers until the closing route unmounts.
/// A showDialog Future may complete before its exit animation finishes.
Future<CampusMapDraft?> showCampusMarkerEditor(
  BuildContext context,
  LatLng point, {
  CampusMapMarker? existing,
}) {
  return showDialog<CampusMapDraft>(
    context: context,
    builder: (_) => _CampusMarkerEditorDialog(
      point: point,
      existing: existing,
    ),
  );
}

class _CampusMarkerEditorDialog extends StatefulWidget {
  const _CampusMarkerEditorDialog({
    required this.point,
    this.existing,
  });

  final LatLng point;
  final CampusMapMarker? existing;

  @override
  State<_CampusMarkerEditorDialog> createState() =>
      _CampusMarkerEditorDialogState();
}

class _CampusMarkerEditorDialogState extends State<_CampusMarkerEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _address;
  late String _kind;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.name ?? '');
    _description = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _address = TextEditingController(text: widget.existing?.address ?? '');
    _kind = widget.existing?.kind ?? 'building';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(CampusMapDraft(
      name: _title.text.trim(),
      description: _description.text.trim(),
      address: _address.text.trim(),
      kind: _kind,
      latitude: widget.point.latitude,
      longitude: widget.point.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null
        ? 'Добавить метку' : 'Изменить метку'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Название'),
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'Укажи название' : null,
            ),
            DropdownButtonFormField<String>(
              value: _kind,
              decoration: const InputDecoration(labelText: 'Тип метки'),
              items: [
                for (final type in campusMarkerKinds.entries)
                  DropdownMenuItem(
                    value: type.key,
                    child: Text(type.value),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _kind = value);
              },
            ),
            TextFormField(
              controller: _address,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Адрес'),
            ),
            TextFormField(
              controller: _description,
              maxLength: 400,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
            const SizedBox(height: 10),
            Text(
              '${widget.point.latitude.toStringAsFixed(6)}, '
              '${widget.point.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _submit,
        child: const Text('Сохранить'),
      ),
    ],
  );
