import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/campus_map_api.dart';

/// Collects a new or edited marker. Only the verified admin calls this UI.
Future<CampusMapDraft?> showCampusMarkerEditor(
  BuildContext context,
  LatLng point, {
  CampusMapMarker? existing,
}) async {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController(text: existing?.name ?? '');
  final description = TextEditingController(text: existing?.description ?? '');
  final address = TextEditingController(text: existing?.address ?? '');
  var kind = existing?.kind ?? 'building';
  try {
    return await showDialog<CampusMapDraft>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: Text(existing == null ? 'Добавить метку' : 'Изменить метку'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    autofocus: true,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Название'),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Укажи название' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: kind,
                    decoration: const InputDecoration(labelText: 'Тип метки'),
                    items: [
                      for (final type in campusMarkerKinds.entries)
                        DropdownMenuItem(
                          value: type.key, child: Text(type.value),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) refresh(() => kind = value);
                    },
                  ),
                  TextFormField(
                    controller: address,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Адрес'),
                  ),
                  TextFormField(
                    controller: description,
                    maxLength: 400,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Описание'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${point.latitude.toStringAsFixed(6)}, '
                    '${point.longitude.toStringAsFixed(6)}',
                    style: Theme.of(dialog).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(dialog, CampusMapDraft(
                  name: title.text.trim(),
                  description: description.text.trim(),
                  address: address.text.trim(),
                  kind: kind,
                  latitude: point.latitude,
                  longitude: point.longitude,
                ));
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  } finally {
    title.dispose();
    address.dispose();
    description.dispose();
  }
}
