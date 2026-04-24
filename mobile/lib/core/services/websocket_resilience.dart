const Duration websocketHeartbeatGracePeriod = Duration(seconds: 45);
const Duration websocketWatchdogInterval = Duration(seconds: 15);

Duration websocketReconnectDelay({required int attempt}) {
  const profileInSeconds = [1, 2, 3, 5, 8, 13, 21, 30];
  final normalizedAttempt = attempt < 0
      ? 0
      : (attempt >= profileInSeconds.length
          ? profileInSeconds.length - 1
          : attempt);
  return Duration(seconds: profileInSeconds[normalizedAttempt]);
}

bool isWebSocketConnectionStale({
  required DateTime now,
  required DateTime? lastActivityAt,
  Duration allowedSilence = websocketHeartbeatGracePeriod,
}) {
  if (lastActivityAt == null) {
    return false;
  }
  return now.difference(lastActivityAt) > allowedSilence;
}
