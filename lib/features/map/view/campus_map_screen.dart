import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final MapController _mapController = MapController();

  static const LatLng _mpeiCenter = LatLng(
    55.7557,
    37.7088,
  );

  final List<CampusPlace> _places = const [
    CampusPlace(
      name: 'Главный учебный корпус',
      description: 'Корпуса А, Б, В, Г, Д',
      address: 'Красноказарменная ул., 17',
      point: LatLng(55.7554, 37.7089),
      icon: Icons.school_outlined,
    ),
    CampusPlace(
      name: 'Административный корпус',
      description: 'Корпуса Ж, З, И, К, Л',
      address: 'Красноказарменная ул., 14',
      point: LatLng(55.7564, 37.7070),
      icon: Icons.account_balance_outlined,
    ),
    CampusPlace(
      name: 'Корпус М',
      description: 'Учебный корпус',
      address: 'Красноказарменная ул., 13',
      point: LatLng(55.7562, 37.7102),
      icon: Icons.apartment_outlined,
    ),
    CampusPlace(
      name: 'Библиотека МЭИ',
      description: 'Научно-техническая библиотека',
      address: 'Красноказарменная ул., 13',
      point: LatLng(55.7560, 37.7106),
      icon: Icons.local_library_outlined,
    ),
    CampusPlace(
      name: 'Корпус Т',
      description: 'Учебный корпус',
      address: 'Красноказарменная ул., 17, стр. 4',
      point: LatLng(55.7549, 37.7110),
      icon: Icons.school_outlined,
    ),
    CampusPlace(
      name: 'Дом культуры МЭИ',
      description: 'ДК МЭИ',
      address: 'Энергетический проезд, 3, стр. 1',
      point: LatLng(55.7539, 37.7130),
      icon: Icons.theater_comedy_outlined,
    ),
    CampusPlace(
      name: 'Бассейн МЭИ',
      description: 'Спортивный комплекс',
      address: 'Энергетический проезд, 3, стр. 3',
      point: LatLng(55.7537, 37.7140),
      icon: Icons.pool_outlined,
    ),
  ];

  CampusPlace? _selectedPlace;

  void _selectPlace(CampusPlace place) {
    setState(() {
      _selectedPlace = place;
    });

    _mapController.move(
      place.point,
      18,
    );
  }

  void _resetMap() {
    setState(() {
      _selectedPlace = null;
    });

    _mapController.move(
      _mpeiCenter,
      16.7,
    );
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
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mpeiCenter,
              initialZoom: 16.7,
              minZoom: 13,
              maxZoom: 20,
              onTap: (_, __) {
                setState(() {
                  _selectedPlace = null;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.campusapp.app',
              ),
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
                attributions: const [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
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

          if (_selectedPlace != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _PlaceCard(
                place: _selectedPlace!,
              ),
            ),

          if (_selectedPlace == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Material(
                color: theme.colorScheme.surface,
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withOpacity(0.10),
                          borderRadius:
                              BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.school,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'НИУ «МЭИ»',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Нажми на корпус на карте',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CampusPlace {
  const CampusPlace({
    required this.name,
    required this.description,
    required this.address,
    required this.point,
    required this.icon,
  });

  final String name;
  final String description;
  final String address;
  final LatLng point;
  final IconData icon;
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

