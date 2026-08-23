/// Small helpers that keep call sites readable without pulling in
/// `package:collection`.
extension IterableX<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }

  E? firstWhereOrNull(bool Function(E element) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }

  /// Sum of [selector] over the iterable.
  double sumOf(double Function(E element) selector) {
    var total = 0.0;
    for (final e in this) {
      total += selector(e);
    }
    return total;
  }
}
