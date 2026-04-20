import 'package:flutter/material.dart';

import '../../data/models/driver_profile.dart';

Future<DriverProfileUpdateInput?> showDriverVehicleSheet({
  required BuildContext context,
  required DriverProfile? profile,
}) {
  return showModalBottomSheet<DriverProfileUpdateInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _DriverVehicleSheet(profile: profile),
  );
}

class _DriverVehicleSheet extends StatefulWidget {
  const _DriverVehicleSheet({required this.profile});

  final DriverProfile? profile;

  @override
  State<_DriverVehicleSheet> createState() => _DriverVehicleSheetState();
}

class _DriverVehicleSheetState extends State<_DriverVehicleSheet> {
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _colorController;
  late final TextEditingController _plateController;

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(
      text: widget.profile?.vehicleBrand ?? '',
    );
    _modelController = TextEditingController(
      text: widget.profile?.vehicleModel ?? '',
    );
    _colorController = TextEditingController(
      text: widget.profile?.vehicleColor ?? '',
    );
    _plateController = TextEditingController(
      text: widget.profile?.plateNumber ?? '',
    );
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mon vehicule',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                _VehicleField(label: 'Marque', controller: _brandController),
                _VehicleField(label: 'Modele', controller: _modelController),
                _VehicleField(label: 'Couleur', controller: _colorController),
                _VehicleField(label: 'Plaque', controller: _plateController),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B8A5A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Enregistrer',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      DriverProfileUpdateInput(
        name: widget.profile?.name,
        profilePhoto: widget.profile?.profilePhoto,
        vehicleBrand: _brandController.text.trim(),
        vehicleModel: _modelController.text.trim(),
        vehicleColor: _colorController.text.trim(),
        plateNumber: _plateController.text.trim(),
      ),
    );
  }
}

class _VehicleField extends StatelessWidget {
  const _VehicleField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF6F7F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
