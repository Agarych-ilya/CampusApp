import 'package:flutter/material.dart';


class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus'),
      ),
      body: Center(
        child: Text('Расписание'),
      ),
    );
  }
}