import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/driver_ride.dart';
import 'countdown_bar.dart';

class RideRequestPopup extends StatefulWidget {
  const RideRequestPopup({
    super.key,
    required this.ride,
    required this.isSubmitting,
    required this.onSend,
    required this.onSkip,
  });

  final DriverRide ride;
  final bool isSubmitting;
  final ValueChanged<double?> onSend;
  final VoidCallback onSkip;

  @override
  State<RideRequestPopup> createState() => _RideRequestPopupState();
}

class _RideRequestPopupState extends State<RideRequestPopup> {
  static const _totalSeconds = 45;

  late final TextEditingController _priceController;
  Timer? _timer;
  int _remainingSeconds = _totalSeconds;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _priceController = TextEditingController(
      text: widget.ride.estimatedPrice.toStringAsFixed(0),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        widget.onSkip();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.38),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                offset: Offset.zero,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NOUVELLE COURSE',
                        style: TextStyle(
                          color: Color(0xFF1B8A5A),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _AddressLine(
                          label: 'Depart', value: widget.ride.pickupLocation),
                      const Padding(
                        padding: EdgeInsets.only(left: 11, top: 4, bottom: 4),
                        child: Icon(Icons.arrow_downward_rounded, size: 20),
                      ),
                      _AddressLine(
                          label: 'Destination',
                          value: widget.ride.dropoffLocation),
                      const SizedBox(height: 18),
                      Text(
                        'Prix client : ${widget.ride.estimatedPrice.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          color: Color(0xFFF5A623),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Proposer un prix',
                          suffixText: 'FCFA',
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _PopupButton(
                              label: 'Envoyer',
                              color: const Color(0xFF1B8A5A),
                              isLoading: widget.isSubmitting,
                              onPressed: widget.isSubmitting
                                  ? null
                                  : () => widget.onSend(
                                        double.tryParse(
                                          _priceController.text.trim(),
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PopupButton(
                              label: 'Skip',
                              color: const Color(0xFFECEFF3),
                              textColor: const Color(0xFF1A1A1A),
                              onPressed:
                                  widget.isSubmitting ? null : widget.onSkip,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CountdownBar(progress: _remainingSeconds / _totalSeconds),
                      const SizedBox(height: 8),
                      Text('Expire dans : ${_remainingSeconds}s'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.place_rounded, color: Color(0xFF1B8A5A)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label : $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _PopupButton extends StatelessWidget {
  const _PopupButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.textColor = Colors.white,
    this.isLoading = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
