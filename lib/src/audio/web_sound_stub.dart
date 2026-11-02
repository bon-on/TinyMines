/// Non-web builds play sounds through the native shell audio channel.
class WebSound {
  void play(String assetKey, double volume) {}

  /// Starts [assetKey] on repeat; false when playback could not start.
  Future<bool> loop(String assetKey, double volume) async => false;

  void stopLoop() {}

  void pauseLoop() {}

  Future<bool> resumeLoop() async => false;
}
