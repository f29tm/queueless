import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/utils/nurse_selection_state.dart';

void main() {
  group('NurseSelectionState — immutable multi-select set', () {
    test('starts empty', () {
      final s = NurseSelectionState.empty();
      expect(s.isEmpty, isTrue);
      expect(s.count, 0);
    });

    test('toggleSelection adds an id, then removes it on second toggle', () {
      final added = NurseSelectionState.empty().toggleSelection('a');
      expect(added.selected.contains('a'), isTrue);
      expect(added.count, 1);
      expect(added.isEmpty, isFalse);

      final removed = added.toggleSelection('a');
      expect(removed.selected.contains('a'), isFalse);
      expect(removed.isEmpty, isTrue);
    });

    test('selectAll adds every id', () {
      final s = NurseSelectionState.empty().selectAll(['a', 'b', 'c']);
      expect(s.count, 3);
      expect(s.selected, {'a', 'b', 'c'});
    });

    test('clearSelection empties the set', () {
      final s = NurseSelectionState.empty().selectAll([
        'a',
        'b',
      ]).clearSelection();
      expect(s.isEmpty, isTrue);
    });

    test('is immutable — original instance is unchanged by operations', () {
      final original = NurseSelectionState.empty().toggleSelection('a');
      original.toggleSelection('b'); // returns a new instance, discarded
      expect(original.selected, {'a'});
    });
  });
}
