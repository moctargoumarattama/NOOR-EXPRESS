import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneInput extends StatelessWidget {
  const PhoneInput({
    super.key,
    required this.controller,
    this.errorText,
  });

  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
      ],
      decoration: InputDecoration(
        labelText: 'Telephone',
        hintText: '90000000',
        prefixText: '+227 ',
        prefixIcon: const Icon(Icons.phone_rounded),
        errorText: errorText,
      ),
    );
  }
}
