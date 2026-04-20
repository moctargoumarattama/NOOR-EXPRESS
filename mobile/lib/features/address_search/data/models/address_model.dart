import '../../domain/entities/address_result.dart';

class AddressModel extends AddressResult {
  const AddressModel({
    required super.name,
    required super.displayName,
    required super.latitude,
    required super.longitude,
    required super.type,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      name: json['name'] as String? ?? 'Adresse',
      displayName: json['display_name'] as String? ?? 'Niamey, Niger',
      latitude: (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['lon'] as num?)?.toDouble() ?? 0,
      type: json['type'] as String? ?? 'address',
    );
  }

  factory AddressModel.fromEntity(AddressResult result) {
    return AddressModel(
      name: result.name,
      displayName: result.displayName,
      latitude: result.latitude,
      longitude: result.longitude,
      type: result.type,
    );
  }

  static const knownNiameyZones = [
    AddressModel(
      name: 'Plateau',
      displayName: 'Plateau, Niamey, Niger',
      latitude: 13.5137,
      longitude: 2.1098,
      type: 'zone',
    ),
    AddressModel(
      name: 'Grand Marche',
      displayName: 'Grand Marche, Niamey, Niger',
      latitude: 13.5116,
      longitude: 2.1247,
      type: 'zone',
    ),
    AddressModel(
      name: 'Aeroport Diori Hamani',
      displayName: 'Aeroport Diori Hamani, Niamey, Niger',
      latitude: 13.4815,
      longitude: 2.1836,
      type: 'zone',
    ),
    AddressModel(
      name: 'Universite Abdou Moumouni',
      displayName: 'Universite Abdou Moumouni, Niamey, Niger',
      latitude: 13.5189,
      longitude: 2.0869,
      type: 'zone',
    ),
    AddressModel(
      name: 'Nouveau Marche',
      displayName: 'Nouveau Marche, Niamey, Niger',
      latitude: 13.5061,
      longitude: 2.1189,
      type: 'zone',
    ),
    AddressModel(
      name: 'Talladje',
      displayName: 'Talladje, Niamey, Niger',
      latitude: 13.4952,
      longitude: 2.1456,
      type: 'zone',
    ),
    AddressModel(
      name: 'Dar Es Salam',
      displayName: 'Dar Es Salam, Niamey, Niger',
      latitude: 13.5234,
      longitude: 2.0912,
      type: 'zone',
    ),
    AddressModel(
      name: 'Yantala',
      displayName: 'Yantala, Niamey, Niger',
      latitude: 13.5089,
      longitude: 2.0734,
      type: 'zone',
    ),
    AddressModel(
      name: 'Route de Tillaberi',
      displayName: 'Route de Tillaberi, Niamey, Niger',
      latitude: 13.5312,
      longitude: 2.0623,
      type: 'zone',
    ),
    AddressModel(
      name: 'Terminus',
      displayName: 'Terminus, Niamey, Niger',
      latitude: 13.5198,
      longitude: 2.1312,
      type: 'zone',
    ),
  ];
}
