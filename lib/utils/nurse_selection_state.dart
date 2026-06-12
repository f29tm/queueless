/// Immutable selection set for the nurse dashboard's multi-select mode.
///
/// Every mutating operation returns a brand-new instance, so widget state can
/// be replaced wholesale (`setState(() => _selection = _selection.toggle(id))`)
/// and the logic stays trivially testable without a widget.
class NurseSelectionState {
  final Set<String> selected;

  const NurseSelectionState(this.selected);

  factory NurseSelectionState.empty() => const NurseSelectionState({});

  bool get isEmpty => selected.isEmpty;

  int get count => selected.length;

  bool contains(String id) => selected.contains(id);

  /// Add [id] if absent, remove it if present.
  NurseSelectionState toggleSelection(String id) {
    final next = Set<String>.of(selected);
    if (!next.add(id)) next.remove(id);
    return NurseSelectionState(next);
  }

  /// Add every id in [ids] to the selection.
  NurseSelectionState selectAll(Iterable<String> ids) =>
      NurseSelectionState(Set<String>.of(selected)..addAll(ids));

  /// Return an empty selection.
  NurseSelectionState clearSelection() => NurseSelectionState.empty();
}
