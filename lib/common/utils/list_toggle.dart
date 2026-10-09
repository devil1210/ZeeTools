extension ListToggle<T> on List<T> {
  // Copia sin [item] si ya estaba, o con él al final si no.
  List<T> toggled(T item) => contains(item) ? ([...this]..remove(item)) : [...this, item];
}
