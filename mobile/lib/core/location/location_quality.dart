enum LocationQuality {
  confirmed,
  approximate,
  manual,
  unknown,
}

LocationQuality locationQualityFromAccuracy(double? accuracyMeters) {
  if (accuracyMeters == null || !accuracyMeters.isFinite || accuracyMeters <= 0) {
    return LocationQuality.unknown;
  }
  if (accuracyMeters <= 50) {
    return LocationQuality.confirmed;
  }
  return LocationQuality.approximate;
}

String locationQualityLabel(LocationQuality quality) {
  switch (quality) {
    case LocationQuality.confirmed:
      return 'Position exacte';
    case LocationQuality.approximate:
      return 'Position approximative - verifiez votre point de depart';
    case LocationQuality.manual:
      return 'Position saisie manuellement';
    case LocationQuality.unknown:
      return '';
  }
}
