import 'package:flutter/material.dart';

import '../models/bike_info.dart';
import '../widgets/cyclix_header.dart';
import '../widgets/cyclix_primary_button.dart';

class BikeDetailScreen extends StatelessWidget {
  const BikeDetailScreen({super.key, required this.bike});

  final BikeInfo bike;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CyclixHeader(showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Bicicleta #${bike.id}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Icon(
                    Icons.pedal_bike,
                    size: 180,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Divider(thickness: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  bike.costPerMinuteDisplay,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                ),
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 20),
              CyclixPrimaryButton(
                label: 'Desbloquear',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Acción pendiente: el backend confirmará el desbloqueo.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
