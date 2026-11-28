import 'package:flutter_test/flutter_test.dart';
import 'package:tshop/src/input/gamepad_action.dart';
import 'package:tshop/src/input/shelf_focus_controller.dart';

void main() {
  group('ShelfFocusController', () {
    test('navigates column-major within a 3-row shelf and clamps bounds', () {
      // Col 0: [e0, e1, e2], Col 1: [e3, e4]
      final controller = ShelfFocusController(
        sections: const [
          ShelfSection(
            id: 'emulators',
            itemIds: ['e0', 'e1', 'e2', 'e3', 'e4'],
            rows: 3,
          ),
        ],
      );
      addTearDown(controller.dispose);

      expect(controller.focusedId, 'e0');
      expect(controller.focusedSectionIndex, 0);
      expect(controller.focusedItemIndex, 0);
      expect(controller.isFocused('e0'), isTrue);
      expect(controller.isFocused('e1'), isFalse);

      // Top clamp.
      expect(controller.move(GamepadAction.up), isFalse);
      expect(controller.focusedId, 'e0');

      // Left clamp.
      expect(controller.move(GamepadAction.left), isFalse);
      expect(controller.focusedId, 'e0');

      // Move down column 0.
      expect(controller.move(GamepadAction.down), isTrue);
      expect(controller.focusedId, 'e1');
      expect(controller.preferredRow, 1);

      expect(controller.move(GamepadAction.down), isTrue);
      expect(controller.focusedId, 'e2');
      expect(controller.preferredRow, 2);

      // Bottom clamp.
      expect(controller.move(GamepadAction.down), isFalse);
      expect(controller.focusedId, 'e2');

      // Move right into partial column 1 (height 2): clamps to row 1 ('e4'),
      // while retaining preferredRow == 2.
      expect(controller.move(GamepadAction.right), isTrue);
      expect(controller.focusedId, 'e4');
      expect(controller.focusedItemIndex, 4);
      expect(controller.preferredRow, 2);

      // Bottom clamp on partial column.
      expect(controller.move(GamepadAction.down), isFalse);
      expect(controller.focusedId, 'e4');

      // Right clamp on last shelf.
      expect(controller.move(GamepadAction.right), isFalse);
      expect(controller.focusedId, 'e4');

      // Moving left restores row 2 ('e2') from preferredRow memory.
      expect(controller.move(GamepadAction.left), isTrue);
      expect(controller.focusedId, 'e2');
      expect(controller.preferredRow, 2);
    });

    test(
      'crosses multiple shelves, skips empty shelves, and restores row memory',
      () {
        // Emulators (3 rows): Col 0 [e0, e1, e2], Col 1 [e3]
        // Empty section in between
        // Utilities (3 rows): Col 0 [u0, u1, u2], Col 1 [u3, u4, u5]
        final controller = ShelfFocusController(
          sections: const [
            ShelfSection(
              id: 'emulators',
              itemIds: ['e0', 'e1', 'e2', 'e3'],
              rows: 3,
            ),
            ShelfSection(id: 'empty', itemIds: [], rows: 3),
            ShelfSection(
              id: 'utilities',
              itemIds: ['u0', 'u1', 'u2', 'u3', 'u4', 'u5'],
              rows: 3,
            ),
          ],
          initialFocusedId: 'e2',
        );
        addTearDown(controller.dispose);

        expect(controller.focusedId, 'e2');
        expect(controller.preferredRow, 2);

        // Cross into short Col 1 of Emulators -> clamps to 'e3', remembers 2.
        expect(controller.move(GamepadAction.right), isTrue);
        expect(controller.focusedId, 'e3');
        expect(controller.focusedSectionIndex, 0);
        expect(controller.preferredRow, 2);

        // Cross past empty section into Utilities Col 0 -> restores row 2.
        expect(controller.move(GamepadAction.right), isTrue);
        expect(controller.focusedId, 'u2');
        expect(controller.focusedSectionIndex, 2);
        expect(controller.focusedItemIndex, 2);
        expect(controller.preferredRow, 2);

        // Move right within Utilities -> stays on row 2 ('u5').
        expect(controller.move(GamepadAction.right), isTrue);
        expect(controller.focusedId, 'u5');

        // Move left back to Utilities Col 0 ('u2'), then across empty shelf
        // to Emulators last column ('e3'), then Col 0 ('e2').
        expect(controller.move(GamepadAction.left), isTrue);
        expect(controller.focusedId, 'u2');
        expect(controller.move(GamepadAction.left), isTrue);
        expect(controller.focusedId, 'e3');
        expect(controller.focusedSectionIndex, 0);
        expect(controller.move(GamepadAction.left), isTrue);
        expect(controller.focusedId, 'e2');
      },
    );

    test('supports 4-row square layout shelves', () {
      // Col 0: [a0, a1, a2, a3], Col 1: [a4, a5]
      final controller = ShelfFocusController(
        sections: const [
          ShelfSection(
            id: 'square',
            itemIds: ['a0', 'a1', 'a2', 'a3', 'a4', 'a5'],
            rows: 4,
          ),
        ],
        initialFocusedId: 'a3',
      );
      addTearDown(controller.dispose);

      expect(controller.preferredRow, 3);
      expect(controller.move(GamepadAction.right), isTrue);
      expect(controller.focusedId, 'a5');
      expect(controller.preferredRow, 3);

      // Moving up from clamped 'a5' (row 1) moves to 'a4' (row 0) and updates
      // preferredRow to 0.
      expect(controller.move(GamepadAction.up), isTrue);
      expect(controller.focusedId, 'a4');
      expect(controller.preferredRow, 0);

      expect(controller.move(GamepadAction.left), isTrue);
      expect(controller.focusedId, 'a0');
    });

    test('focus(id) syncs preferredRow and ignores unknown ids', () {
      final controller = ShelfFocusController(
        sections: const [
          ShelfSection(
            id: 'emulators',
            itemIds: ['e0', 'e1', 'e2', 'e3'],
            rows: 3,
          ),
          ShelfSection(
            id: 'utilities',
            itemIds: ['u0', 'u1', 'u2'],
            rows: 3,
          ),
        ],
        initialFocusedId: 'e2',
      );
      addTearDown(controller.dispose);

      // Move right onto clamped 'e3' (row 0) with preferredRow still 2.
      controller.move(GamepadAction.right);
      expect(controller.focusedId, 'e3');
      expect(controller.preferredRow, 2);

      // Touching 'e3' explicitly syncs preferredRow to its actual row (0).
      expect(controller.focus('e3'), isFalse);
      expect(controller.preferredRow, 0);

      // Now moving right lands on row 0 ('u0'), not row 2 ('u2').
      expect(controller.move(GamepadAction.right), isTrue);
      expect(controller.focusedId, 'u0');

      // Direct touch jump to 'u2' syncs preferredRow to 2 and notifies.
      var notifications = 0;
      controller.addListener(() => notifications++);
      expect(controller.focus('u2'), isTrue);
      expect(controller.focusedId, 'u2');
      expect(controller.preferredRow, 2);
      expect(notifications, 1);

      // Unknown id is ignored safely.
      expect(controller.focus('missing'), isFalse);
      expect(controller.focusedId, 'u2');
      expect(notifications, 1);
    });

    test('ignores non-directional actions in move()', () {
      final controller = ShelfFocusController(
        sections: const [
          ShelfSection(id: 'emulators', itemIds: ['e0', 'e1'], rows: 3),
        ],
      );
      addTearDown(controller.dispose);

      for (final action in [
        GamepadAction.confirm,
        GamepadAction.back,
        GamepadAction.secondary,
        GamepadAction.searchOrRetry,
        GamepadAction.tabPrev,
        GamepadAction.tabNext,
        GamepadAction.menu,
      ]) {
        expect(controller.move(action), isFalse);
      }
      expect(controller.focusedId, 'e0');
    });

    test(
      'updateSections preserves focus, recovers nearest item, and handles '
      'empty states',
      () {
        final controller = ShelfFocusController(
          sections: const [
            ShelfSection(id: 'queue', itemIds: ['q0', 'q1', 'q2'], rows: 3),
            ShelfSection(id: 'updates', itemIds: ['u0', 'u1'], rows: 3),
          ],
          initialFocusedId: 'q1',
        );
        addTearDown(controller.dispose);

        var notifications = 0;
        controller
          ..addListener(() => notifications++)
          // Same sections -> no change, no spurious notification.
          ..updateSections(const [
            ShelfSection(id: 'queue', itemIds: ['q0', 'q1', 'q2'], rows: 3),
            ShelfSection(id: 'updates', itemIds: ['u0', 'u1'], rows: 3),
          ]);
        expect(controller.focusedId, 'q1');
        expect(notifications, 0);

        // Focused item moves to another section (Library install completes).
        controller.updateSections(const [
          ShelfSection(id: 'queue', itemIds: ['q0', 'q2'], rows: 3),
          ShelfSection(id: 'updates', itemIds: ['u0', 'u1'], rows: 3),
          ShelfSection(id: 'installed', itemIds: ['q1'], rows: 3),
        ]);
        expect(controller.focusedId, 'q1');
        expect(controller.focusedSectionIndex, 2);
        expect(controller.focusedItemIndex, 0);
        expect(notifications, 1);

        // Focus 'q2' in queue, then remove 'q2' -> selects nearest item ('q0').
        controller
          ..focus('q2')
          ..updateSections(const [
            ShelfSection(id: 'queue', itemIds: ['q0'], rows: 3),
            ShelfSection(id: 'updates', itemIds: ['u0', 'u1'], rows: 3),
          ]);
        expect(controller.focusedId, 'q0');
        expect(controller.focusedSectionIndex, 0);

        // Remove entire queue section -> falls forward to nearest shelf
        // ('updates').
        controller.updateSections(const [
          ShelfSection(id: 'updates', itemIds: ['u0', 'u1'], rows: 3),
        ]);
        expect(controller.focusedId, 'u0');
        expect(controller.focusedSectionIndex, 0);

        // All sections empty -> focusedId becomes null.
        controller.updateSections(const []);
        expect(controller.focusedId, isNull);
        expect(controller.focusedSectionIndex, isNull);
        expect(controller.focusedItemIndex, isNull);

        // Repopulating selects first valid item again.
        controller.updateSections(const [
          ShelfSection(id: 'empty', itemIds: [], rows: 3),
          ShelfSection(id: 'emulators', itemIds: ['dolphin'], rows: 3),
        ]);
        expect(controller.focusedId, 'dolphin');
        expect(controller.focusedSectionIndex, 1);
        expect(controller.focusedItemIndex, 0);
      },
    );
  });
}
