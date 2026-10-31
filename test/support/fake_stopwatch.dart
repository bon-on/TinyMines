/// Stopwatch whose time only moves when a test calls [advance], so widget
/// tests can control elapsed time exactly (real stopwatches ignore fake async).
class FakeStopwatch implements Stopwatch {
  int _ms = 0;
  bool _running = false;

  /// Adds [milliseconds] to the elapsed time if the watch is running.
  void advance(int milliseconds) {
    if (_running) _ms += milliseconds;
  }

  @override
  void start() => _running = true;

  @override
  void stop() => _running = false;

  @override
  void reset() => _ms = 0;

  @override
  bool get isRunning => _running;

  @override
  int get elapsedMilliseconds => _ms;

  @override
  Duration get elapsed => Duration(milliseconds: _ms);

  @override
  int get elapsedMicroseconds => _ms * 1000;

  @override
  int get elapsedTicks => elapsedMicroseconds;

  @override
  int get frequency => 1000000;
}
