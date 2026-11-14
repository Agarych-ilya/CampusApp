import 'dart:async';

import 'package:flutter/material.dart';

import '../data/schedule_api.dart';

/// Search MPEI groups without changing the student's BARS group.
class ScheduleGroupPicker extends StatefulWidget {
  const ScheduleGroupPicker({
    super.key,
    required this.api,
    required this.currentGroup,
  });

  final ScheduleApi api;
  final String currentGroup;

  @override
  State<ScheduleGroupPicker> createState() => _ScheduleGroupPickerState();
}

class _ScheduleGroupPickerState extends State<ScheduleGroupPicker> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;
  List<String> _groups = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.currentGroup;
    _lookup(widget.currentGroup);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String input) {
    _debounce?.cancel();
    // Invalidate any in-flight search immediately, not only after debounce.
    _requestId++;
    setState(() {
      _groups = [];
      _error = null;
      _loading = false;
    });
    final term = input.trim();
    if (term.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 320), () => _lookup(term));
  }

  Future<void> _lookup(String query) async {
    final requestId = ++_requestId;
    if (query.trim().length < 2) return;
    if (mounted) setState(() => _loading = true);
    try {
      final found = await widget.api.searchGroups(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _groups = found;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _choose(String group) {
    final selected = group.trim();
    if (selected.isEmpty) return;
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final term = _searchController.text.trim();
    final exactMatch = _groups.any(
      (item) => item.toLowerCase() == term.toLowerCase(),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: SizedBox(
          height: (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom - 110)
              .clamp(180.0, 410.0)
              .toDouble(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выбрать расписание группы',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (text) => _choose(text),
                decoration: InputDecoration(
                  hintText: 'Например, А-03-23',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: term.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            _onChanged('');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(group),
                      trailing: group == widget.currentGroup
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => _choose(group),
                    );
                  },
                ),
              ),
              if (term.isNotEmpty && !exactMatch)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _choose(term),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text('Открыть «$term»'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
