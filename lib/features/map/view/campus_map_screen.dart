import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/campus_map_api.dart';
import '../data/campus_map_preferences.dart';
import '/features/services/data/community_admin_api.dart';
import 'campus_marker_editor.dart';

typedef CampusPlace = CampusMapMarker;

extension _PlaceIcon on CampusMapMarker {
  IconData get icon => switch (kind) {
    'library' => Icons.local_library_outlined,
    'sports' => Icons.pool_outlined,
    'culture' => Icons.theater_comedy_outlined,
    'service' => Icons.storefront_outlined,
    'other' => Icons.place_outlined,
    _ => Icons.school_outlined,
  };
}


class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key, this.api, this.adminApi});
  final CampusMapApi? api;
  final CommunityAdminApi? adminApi;

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final MapController _mapController = MapController();

  static const LatLng _mpeiCenter = LatLng(
    55.7557,
    37.7088,
  );

  List<CampusMapMarker> _places = const [
    CampusMapMarker(id: 'seed-1',
      name: 'Главный учебный корпус',
      description: 'Корпуса А, Б, В, Г, Д',
      address: 'Красноказарменная ул., 17',
      latitude: 55.7554, longitude: 37.7089, kind: 'building',
    ),
    CampusMapMarker(id: 'seed-2',
      name: 'Административный корпус',
      description: 'Корпуса Ж, З, И, К, Л',
      address: 'Красноказарменная ул., 14',
      latitude: 55.7564, longitude: 37.7070, kind: 'building',
    ),
    CampusMapMarker(id: 'seed-3',
      name: 'Корпус М',
      description: 'Учебный корпус',
      address: 'Красноказарменная ул., 13',
      latitude: 55.7562, longitude: 37.7102, kind: 'building',
    ),
    CampusMapMarker(id: 'seed-4',
      name: 'Библиотека МЭИ',
      description: 'Научно-техническая библиотека',
      address: 'Красноказарменная ул., 13',
      latitude: 55.7560, longitude: 37.7106, kind: 'library',
    ),
    CampusMapMarker(id: 'seed-5',
      name: 'Корпус Т',
      description: 'Учебный корпус',
      address: 'Красноказарменная ул., 17, стр. 4',
      latitude: 55.7549, longitude: 37.7110, kind: 'building',
    ),
    CampusMapMarker(id: 'seed-6',
      name: 'Дом культуры МЭИ',
      description: 'ДК МЭИ',
      address: 'Энергетический проезд, 3, стр. 1',
      latitude: 55.7539, longitude: 37.7130, kind: 'culture',
    ),
    CampusMapMarker(id: 'seed-7',
      name: 'Бассейн МЭИ',
      description: 'Спортивный комплекс',
      address: 'Энергетический проезд, 3, стр. 3',
      latitude: 55.7537, longitude: 37.7140, kind: 'sports',
    ),
  ];

  CampusPlace? _selectedPlace;
  CampusMapMarker? _movingMarker;
  late final CampusMapApi _api = widget.api ?? CampusMapApi();
  late final CommunityAdminApi _admin = widget.adminApi ??
      CommunityAdminApi.instance;
  bool _adminMode = false;
  bool _serverReady = false;
  bool _busy = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    CampusMapPreferences.load();
    _refresh();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _notice(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _refresh() async {
    try {
      final markers = await _api.list();
      if (!mounted) return;
      setState(() {
        _places = markers;
        _serverReady = true;
        _loadError = null;
        if (_selectedPlace != null) {
          final matches = markers.where((m) => m.id == _selectedPlace!.id);
          _selectedPlace = matches.isEmpty ? null : matches.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverReady = false;
        _adminMode = false;
        _loadError = 'Нет связи с бэкендом — показаны исходные ориентиры';
      });
    }
  }

  Future<void> _toggleAdmin() async {
    if (_adminMode) {
      setState(() {
        _adminMode = false;
        _movingMarker = null;
      });
      return;
    }
    if (!_serverReady) {
      _notice('Для изменения меток нужен бэкенд CampusApp');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final permitted = await _admin.ensureBarsAdminSession();
      if (!mounted) return;
      if (permitted) {
        setState(() => _adminMode = true);
        _notice('Долгое нажатие на карту — добавить метку');
      } else {
        _notice(_admin.lastBarsAuthError ?? 'Нет прав администратора');
      }
    } catch (e) {
      _notice('Не удалось проверить администратора: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(LatLng point, {CampusMapMarker? old}) async {
    if (!_adminMode || !_serverReady || _busy) return;
    final draft = await showCampusMarkerEditor(context, point, existing: old);
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = old == null
          ? await _api.create(draft) : await _api.update(old.id,draft);
      if (!mounted) return;
      setState(() {
        _places = [
          for (final marker in _places)
            if (marker.id != updated.id) marker,
          updated,
        ];
        _selectedPlace = updated;
      });
      _notice(old == null ? 'Метка добавлена' : 'Метка обновлена');
    } catch (e) {
      _notice('Не удалось сохранить метку: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moveTo(LatLng point) async {
    final selected = _movingMarker;
    if (selected == null || !_adminMode || _busy) return;
    setState(() => _busy = true);
    try {
      final draft = CampusMapDraft.fromMarker(selected);
      final moved = await _api.update(selected.id, CampusMapDraft(
        name: draft.name, description: draft.description,
        address: draft.address, kind: draft.kind,
        latitude: point.latitude, longitude: point.longitude,
      ));
      if (!mounted) return;
      setState(() {
        _places = [
          for (final marker in _places)
            if (marker.id != moved.id) marker,
          moved,
        ];
        _selectedPlace = moved;
        _movingMarker = null;
      });
      _notice('Метка перемещена');
    } catch (e) {
      _notice('Не удалось переместить: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(CampusMapMarker place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Удалить метку?'),
        content: Text('«' + place.name + '» исчезнет у всех студентов.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog,false),
            child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialog,true),
            child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm != true || !mounted || !_adminMode) return;
    setState(() => _busy = true);
    try {
      await _api.delete(place.id);
      if (!mounted) return;
      setState(() {
        _places = _places.where((m) => m.id != place.id).toList();
        _selectedPlace = null;
      });
      _notice('Метка удалена');
    } catch (e) {
      _notice('Не удалось удалить: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _actions(CampusMapMarker place) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(child: Wrap(children: [
        ListTile(title: Text(place.name),
          subtitle: const Text('Управление меткой'),),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Изменить название и описание'),
          onTap: () => Navigator.pop(sheet,'edit'),
        ),
        ListTile(
          leading: const Icon(Icons.open_with),
          title: const Text('Переместить на карте'),
          onTap: () => Navigator.pop(sheet,'move'),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Удалить метку'),
          onTap: () => Navigator.pop(sheet,'delete'),
        ),
      ])),
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _save(place.point, old: place);
        break;
      case 'move':
        setState(() {
          _movingMarker = place;
          _selectedPlace = null;
        });
        _notice('Нажми на карте, куда переместить метку');
        break;
      case 'delete':
        await _remove(place);
        break;
    }
  }

  void _zoom(double by) {
    final camera = _mapController.camera;
    final next = (camera.zoom + by).clamp(13.0,19.0).toDouble();
    _mapController.move(camera.center,next);
  }

  List<Widget> _tiles(CampusMapType type) {
    const esri = 'https://server.arcgisonline.com/ArcGIS/rest/services/';
    if (type == CampusMapType.standard) {
      return [TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName:'com.campusapp.app',
      )];
    }
    final satellite = type == CampusMapType.satellite ||
        type == CampusMapType.hybrid;
    return [
      TileLayer(
        urlTemplate: esri +
            (satellite ? 'World_Imagery' : 'World_Topo_Map') +
            '/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName:'com.campusapp.app',
      ),
      if (type == CampusMapType.hybrid) TileLayer(
        urlTemplate: esri +
          'Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName:'com.campusapp.app',
      ),
    ];
  }


  void _selectPlace(CampusPlace place) {
    setState(() => _selectedPlace = place);
    final zoom = _mapController.camera.zoom;
    _mapController.move(place.point,zoom < 17 ? 17 : zoom);
    if (_adminMode) _actions(place);
  }

  void _resetMap() {
    setState(() {
      _selectedPlace = null;
      _movingMarker = null;
    });
    _mapController.move(_mpeiCenter,16.7);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Кампус МЭИ',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(width: 18,height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            key: const ValueKey('campus-map-admin'),
            onPressed: _toggleAdmin,
            tooltip: _adminMode ? 'Завершить редактирование'
                : 'Редактировать метки (администратор)',
            icon: Icon(_adminMode ? Icons.check_circle_outline
                : Icons.edit_location_alt_outlined),
          ),
          IconButton(
            onPressed: _resetMap,
            icon: const Icon(
              Icons.center_focus_strong,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ValueListenableBuilder<CampusMapType>(
            valueListenable: CampusMapPreferences.selected,
            builder: (context,type,_) => FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mpeiCenter,
              initialZoom: 16.7,
              minZoom: 13,
              maxZoom: 19,
              onTap: (_, point) {
                if (_movingMarker != null) {
                  _moveTo(point);
                } else {
                  setState(() => _selectedPlace = null);
                }
              },
              onLongPress: (_, point) {
                if (_adminMode && _movingMarker == null) _save(point);
              },
            ),
            children: [
              ..._tiles(type),
              MarkerLayer(
                markers: _places.map((place) {
                  final selected =
                      _selectedPlace == place;

                  return Marker(
                    point: place.point,
                    width: selected ? 64 : 52,
                    height: selected ? 64 : 52,
                    child: GestureDetector(
                      onTap: () {
                        _selectPlace(place);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 180,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primary
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                theme.colorScheme.primary,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 8,
                              color: Color(0x30000000),
                            ),
                          ],
                        ),
                        child: Icon(
                          place.icon,
                          color: selected
                              ? Colors.white
                              : theme.colorScheme.primary,
                          size: selected ? 30 : 25,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(type == CampusMapType.standard
                      ? '© OpenStreetMap contributors'
                      : 'Tiles © Esri and contributors'),
                ],
              ),
            ],
          ),
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _CampusSearchBar(
              places: _places,
              onSelected: _selectPlace,
            ),
          ),

          Positioned(
            right: 14,
            top: 90,
            child: Column(children: [
              Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                child: IconButton(
                  key: const ValueKey('campus-map-zoom-in'),
                  tooltip: 'Приблизить',
                  onPressed: () => _zoom(1),
                  icon: const Icon(Icons.add),
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                child: IconButton(
                  key: const ValueKey('campus-map-zoom-out'),
                  tooltip: 'Отдалить',
                  onPressed: () => _zoom(-1),
                  icon: const Icon(Icons.remove),
                ),
              ),
            ]),
          ),
          if (_loadError != null)
            Positioned(
              left: 16, right: 72, bottom: 98,
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _refresh,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_loadError! + '. Нажми для повтора',
                      style: theme.textTheme.bodySmall),
                  ),
                ),
              ),
            ),
          if (_adminMode && _movingMarker != null)
            Positioned(
              top: 96, left: 12, right: 70,
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  dense: true,
                  title: const Text('Выбери новое место для метки'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _movingMarker = null),
                  ),
                ),
              ),
            ),
          if (_adminMode && _movingMarker == null && _selectedPlace == null)
            Positioned(
              left: 12, right: 70, bottom: 98,
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Удерживай палец на карте для новой метки'),
                ),
              ),
            ),
          if (_selectedPlace != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 94,
              child: _PlaceCard(
                place: _selectedPlace!,
              ),
            ),


        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
  });

  final CampusPlace place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 5,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                place.icon,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style:
                        theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.description,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.address,
                    style:
                        theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampusSearchBar extends StatefulWidget {
  const _CampusSearchBar({
    required this.places,
    required this.onSelected,
  });

  final List<CampusPlace> places;
  final ValueChanged<CampusPlace> onSelected;

  @override
  State<_CampusSearchBar> createState() =>
      _CampusSearchBarState();
}

class _CampusSearchBarState
    extends State<_CampusSearchBar> {
  final TextEditingController _controller =
      TextEditingController();

  bool _showResults = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<CampusPlace> get _results {
    final query =
        _controller.text.trim().toLowerCase();

    if (query.isEmpty) {
      return [];
    }

    return widget.places.where((place) {
      return place.name.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Column(
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(20),
          child: TextField(
            controller: _controller,
            onChanged: (_) {
              setState(() {
                _showResults =
                    _controller.text.trim().isNotEmpty;
              });
            },
            decoration: InputDecoration(
              hintText: 'Найти корпус или место',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _controller.clear();

                        setState(() {
                          _showResults = false;
                        });
                      },
                      icon: const Icon(Icons.close),
                    )
                  : null,
              filled: true,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius:
                    BorderRadius.circular(20),
              ),
            ),
          ),
        ),

        if (_showResults && results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints:
                const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final place = results[index];

                return ListTile(
                  leading: Icon(place.icon),
                  title: Text(place.name),
                  subtitle: Text(place.address),
                  onTap: () {
                    _controller.text = place.name;

                    setState(() {
                      _showResults = false;
                    });

                    widget.onSelected(place);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

