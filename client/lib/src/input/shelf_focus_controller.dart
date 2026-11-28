import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:tshop/src/input/gamepad_action.dart';

/// A single framed column-major shelf section containing focusable items.
///
/// Items fill top-to-bottom within each column up to [rows], then advance
/// left-to-right to the next column (for example 3 rows on AYN Thor
/// `837×471` or 4 rows on square `592×516` displays).
@immutable
final class ShelfSection {
  /// Creates a shelf section with [id], ordered [itemIds], and [rows] per
  /// column.
  const ShelfSection({
    required this.id,
    required this.itemIds,
    required this.rows,
  }) : assert(rows > 0, 'ShelfSection.rows must be greater than zero.');

  /// Stable section identifier (for example a category or Library state).
  final String id;

  /// Ordered ids of focusable cells in this shelf (lead cell + tiles).
  final List<String> itemIds;

  /// Number of rows per column in this shelf.
  final int rows;

  /// Safe positive row count used for column-major indexing.
  int get safeRows => rows < 1 ? 1 : rows;

  /// Whether this section has no focusable items.
  bool get isEmpty => itemIds.isEmpty;

  /// Whether this section has at least one focusable item.
  bool get isNotEmpty => itemIds.isNotEmpty;

  /// Total number of columns occupied by [itemIds].
  int get columnCount {
    if (itemIds.isEmpty) {
      return 0;
    }
    return (itemIds.length + safeRows - 1) ~/ safeRows;
  }

  /// Zero-based index of the rightmost column, or `0` when empty.
  int get lastColumn => math.max(0, columnCount - 1);

  /// Number of items present in zero-based [column].
  int rowsInColumn(int column) {
    if (itemIds.isEmpty || column < 0 || column >= columnCount) {
      return 0;
    }
    final remaining = itemIds.length - column * safeRows;
    return math.min(safeRows, remaining);
  }

  /// Returns the item id at [column] and [row], clamping both within bounds,
  /// or `null` if this section is empty.
  String? itemAt({required int column, required int row}) {
    if (itemIds.isEmpty) {
      return null;
    }
    final clampedCol = column.clamp(0, lastColumn);
    final colHeight = rowsInColumn(clampedCol);
    final clampedRow = row.clamp(0, colHeight - 1);
    return itemIds[clampedCol * safeRows + clampedRow];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ShelfSection &&
            other.id == id &&
            other.rows == rows &&
            listEquals(other.itemIds, itemIds));
  }

  @override
  int get hashCode => Object.hash(id, rows, Object.hashAll(itemIds));

  @override
  String toString() =>
      'ShelfSection(id: $id, rows: $rows, itemIds: ${itemIds.length})';
}

/// Hand-rolled neighbour-graph focus controller for column-major framed
/// shelves.
///
/// Faithfully implements the shelf navigation semantics from `design/nav.ts`:
/// - Up/down moves within the active column, clamping at the top/bottom and
///   updating [preferredRow].
/// - Left/right moves across columns within the current shelf or crosses into
///   the previous/next non-empty shelf, restoring [preferredRow] clamped to
///   the target column's height without losing [preferredRow].
/// - Touch taps or programmatic jumps call [focus] to sync [preferredRow].
/// - [updateSections] preserves focus when the focused item still exists, or
///   recovers to the nearest valid item when items move or disappear.
final class ShelfFocusController extends ChangeNotifier {
  /// Creates a focus controller initialized with [sections] and an optional
  /// [initialFocusedId].
  ShelfFocusController({
    List<ShelfSection> sections = const <ShelfSection>[],
    String? initialFocusedId,
  }) : _sections = List<ShelfSection>.unmodifiable(sections) {
    if (initialFocusedId != null) {
      final cursor = _cursorForId(_sections, initialFocusedId);
      if (cursor != null) {
        _applyCursor(cursor, syncPreferredRow: true);
        return;
      }
    }
    final first = _firstCursor(_sections);
    if (first != null) {
      _applyCursor(first, syncPreferredRow: true);
    }
  }

  List<ShelfSection> _sections;
  String? _focusedId;
  int? _focusedSectionIndex;
  int? _focusedItemIndex;
  int _preferredRow = 0;

  /// Current shelf sections managed by this controller.
  List<ShelfSection> get sections => _sections;

  /// Id of the currently focused cell, or `null` when all shelves are empty.
  String? get focusedId => _focusedId;

  /// Zero-based index of the section containing [focusedId], or `null`.
  int? get focusedSectionIndex => _focusedSectionIndex;

  /// Zero-based index of [focusedId] inside its [ShelfSection.itemIds], or
  /// `null`.
  int? get focusedItemIndex => _focusedItemIndex;

  /// Remembered row index preserved across horizontal column/shelf moves.
  int get preferredRow => _preferredRow;

  /// Whether [id] is the currently focused cell.
  bool isFocused(String id) => _focusedId != null && _focusedId == id;

  /// Replaces the active shelf layout with [sections].
  ///
  /// Preserves [focusedId] if still present in [sections]. Otherwise selects
  /// the nearest valid item (or `null` when every section is empty).
  void updateSections(List<ShelfSection> sections) {
    final prevFocusedId = _focusedId;
    final prevSectionIndex = _focusedSectionIndex;
    final prevItemIndex = _focusedItemIndex;
    final prevSectionId =
        prevSectionIndex != null && prevSectionIndex < _sections.length
        ? _sections[prevSectionIndex].id
        : null;
    final prevCursor = prevFocusedId == null
        ? null
        : _cursorForId(_sections, prevFocusedId);

    _sections = List<ShelfSection>.unmodifiable(sections);

    if (_firstNonEmptySectionIndex(_sections) == null) {
      final changed =
          _focusedId != null ||
          _focusedSectionIndex != null ||
          _focusedItemIndex != null;
      _focusedId = null;
      _focusedSectionIndex = null;
      _focusedItemIndex = null;
      _preferredRow = 0;
      if (changed) {
        notifyListeners();
      }
      return;
    }

    if (prevFocusedId != null) {
      final preserved = _cursorForId(_sections, prevFocusedId);
      if (preserved != null) {
        final newSectionId = _sections[preserved.sectionIndex].id;
        final movedSection = prevSectionId != newSectionId;
        final changed =
            _focusedSectionIndex != preserved.sectionIndex ||
            _focusedItemIndex != preserved.itemIndex;
        _applyCursor(preserved, syncPreferredRow: movedSection);
        if (changed) {
          notifyListeners();
        }
        return;
      }

      final recovered = _findNearestCursor(
        _sections,
        prevSectionId: prevSectionId,
        prevSectionIndex: prevSectionIndex ?? 0,
        prevItemIndex: prevItemIndex ?? 0,
        preferredRow: prevCursor?.row ?? _preferredRow,
      );
      if (recovered != null) {
        _applyCursor(recovered, syncPreferredRow: true);
        notifyListeners();
      }
      return;
    }

    final first = _firstCursor(_sections);
    if (first != null) {
      _applyCursor(first, syncPreferredRow: true);
      notifyListeners();
    }
  }

  /// Moves focus according to directional [direction].
  ///
  /// Non-directional [GamepadAction]s are ignored and return `false`.
  /// Returns `true` when focus moved to a different item.
  bool move(GamepadAction direction) {
    switch (direction) {
      case GamepadAction.up:
      case GamepadAction.down:
      case GamepadAction.left:
      case GamepadAction.right:
        break;
      case GamepadAction.confirm:
      case GamepadAction.back:
      case GamepadAction.secondary:
      case GamepadAction.searchOrRetry:
      case GamepadAction.tabPrev:
      case GamepadAction.tabNext:
      case GamepadAction.menu:
        return false;
    }

    if (_firstNonEmptySectionIndex(_sections) == null) {
      if (_focusedId != null) {
        _focusedId = null;
        _focusedSectionIndex = null;
        _focusedItemIndex = null;
        _preferredRow = 0;
        notifyListeners();
        return true;
      }
      return false;
    }

    final current = _focusedId == null
        ? null
        : _cursorForId(_sections, _focusedId!);
    if (current == null) {
      final first = _firstCursor(_sections)!;
      _applyCursor(first, syncPreferredRow: true);
      notifyListeners();
      return true;
    }

    final section = _sections[current.sectionIndex];
    _ShelfCursor? next;
    var syncRow = false;

    switch (direction) {
      case GamepadAction.up:
        if (current.row == 0) {
          return false;
        }
        next = _cursorAt(
          _sections,
          sectionIndex: current.sectionIndex,
          col: current.col,
          row: current.row - 1,
        );
        syncRow = true;

      case GamepadAction.down:
        if (current.row + 1 >= section.rowsInColumn(current.col)) {
          return false;
        }
        next = _cursorAt(
          _sections,
          sectionIndex: current.sectionIndex,
          col: current.col,
          row: current.row + 1,
        );
        syncRow = true;

      case GamepadAction.left:
        if (current.col > 0) {
          next = _cursorAt(
            _sections,
            sectionIndex: current.sectionIndex,
            col: current.col - 1,
            row: _preferredRow,
          );
        } else {
          final prevSectionIdx = _findPreviousNonEmptySection(
            _sections,
            before: current.sectionIndex,
          );
          if (prevSectionIdx == null) {
            return false;
          }
          final prevSection = _sections[prevSectionIdx];
          next = _cursorAt(
            _sections,
            sectionIndex: prevSectionIdx,
            col: prevSection.lastColumn,
            row: _preferredRow,
          );
        }

      case GamepadAction.right:
        if (current.col < section.lastColumn) {
          next = _cursorAt(
            _sections,
            sectionIndex: current.sectionIndex,
            col: current.col + 1,
            row: _preferredRow,
          );
        } else {
          final nextSectionIdx = _findNextNonEmptySection(
            _sections,
            after: current.sectionIndex,
          );
          if (nextSectionIdx == null) {
            return false;
          }
          next = _cursorAt(
            _sections,
            sectionIndex: nextSectionIdx,
            col: 0,
            row: _preferredRow,
          );
        }

      case GamepadAction.confirm:
      case GamepadAction.back:
      case GamepadAction.secondary:
      case GamepadAction.searchOrRetry:
      case GamepadAction.tabPrev:
      case GamepadAction.tabNext:
      case GamepadAction.menu:
        return false;
    }

    if (next == null) {
      return false;
    }
    final changed =
        next.id != _focusedId ||
        next.sectionIndex != _focusedSectionIndex ||
        next.itemIndex != _focusedItemIndex;
    _applyCursor(next, syncPreferredRow: syncRow);
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  /// Directly focuses [id] (for example on touch tap, hover, or programmatic
  /// jump) and synchronizes [preferredRow] to that item's row.
  ///
  /// Returns `true` if [id] exists in [sections] and focus changed.
  bool focus(String id) {
    final cursor = _cursorForId(_sections, id);
    if (cursor == null) {
      return false;
    }
    final changed =
        _focusedId != cursor.id ||
        _focusedSectionIndex != cursor.sectionIndex ||
        _focusedItemIndex != cursor.itemIndex;
    _applyCursor(cursor, syncPreferredRow: true);
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  void _applyCursor(_ShelfCursor cursor, {required bool syncPreferredRow}) {
    _focusedId = cursor.id;
    _focusedSectionIndex = cursor.sectionIndex;
    _focusedItemIndex = cursor.itemIndex;
    if (syncPreferredRow) {
      _preferredRow = cursor.row;
    }
  }
}

final class _ShelfCursor {
  const _ShelfCursor({
    required this.id,
    required this.sectionIndex,
    required this.itemIndex,
    required this.col,
    required this.row,
  });

  final String id;
  final int sectionIndex;
  final int itemIndex;
  final int col;
  final int row;
}

_ShelfCursor? _cursorForId(List<ShelfSection> sections, String id) {
  for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
    final section = sections[sectionIndex];
    final itemIndex = section.itemIds.indexOf(id);
    if (itemIndex != -1) {
      final rows = section.safeRows;
      return _ShelfCursor(
        id: id,
        sectionIndex: sectionIndex,
        itemIndex: itemIndex,
        col: itemIndex ~/ rows,
        row: itemIndex % rows,
      );
    }
  }
  return null;
}

_ShelfCursor? _cursorAt(
  List<ShelfSection> sections, {
  required int sectionIndex,
  required int col,
  required int row,
}) {
  if (sectionIndex < 0 || sectionIndex >= sections.length) {
    return null;
  }
  final section = sections[sectionIndex];
  if (section.isEmpty) {
    return null;
  }
  final clampedCol = col.clamp(0, section.lastColumn);
  final colHeight = section.rowsInColumn(clampedCol);
  final clampedRow = row.clamp(0, colHeight - 1);
  final itemIndex = clampedCol * section.safeRows + clampedRow;
  return _ShelfCursor(
    id: section.itemIds[itemIndex],
    sectionIndex: sectionIndex,
    itemIndex: itemIndex,
    col: clampedCol,
    row: clampedRow,
  );
}

_ShelfCursor? _firstCursor(List<ShelfSection> sections) {
  final firstSection = _firstNonEmptySectionIndex(sections);
  if (firstSection == null) {
    return null;
  }
  return _cursorAt(sections, sectionIndex: firstSection, col: 0, row: 0);
}

int? _firstNonEmptySectionIndex(List<ShelfSection> sections) {
  for (var i = 0; i < sections.length; i++) {
    if (sections[i].isNotEmpty) {
      return i;
    }
  }
  return null;
}

int? _findPreviousNonEmptySection(
  List<ShelfSection> sections, {
  required int before,
}) {
  for (var i = before - 1; i >= 0; i--) {
    if (sections[i].isNotEmpty) {
      return i;
    }
  }
  return null;
}

int? _findNextNonEmptySection(
  List<ShelfSection> sections, {
  required int after,
}) {
  for (var i = after + 1; i < sections.length; i++) {
    if (sections[i].isNotEmpty) {
      return i;
    }
  }
  return null;
}

_ShelfCursor? _findNearestCursor(
  List<ShelfSection> sections, {
  required String? prevSectionId,
  required int prevSectionIndex,
  required int prevItemIndex,
  required int preferredRow,
}) {
  if (prevSectionId != null) {
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      if (section.id == prevSectionId && section.isNotEmpty) {
        final itemIndex = prevItemIndex.clamp(0, section.itemIds.length - 1);
        final rows = section.safeRows;
        return _ShelfCursor(
          id: section.itemIds[itemIndex],
          sectionIndex: i,
          itemIndex: itemIndex,
          col: itemIndex ~/ rows,
          row: itemIndex % rows,
        );
      }
    }
  }

  for (var i = math.max(0, prevSectionIndex); i < sections.length; i++) {
    if (sections[i].isNotEmpty) {
      return _cursorAt(
        sections,
        sectionIndex: i,
        col: 0,
        row: preferredRow,
      );
    }
  }

  for (
    var i = math.min(prevSectionIndex - 1, sections.length - 1);
    i >= 0;
    i--
  ) {
    if (sections[i].isNotEmpty) {
      return _cursorAt(
        sections,
        sectionIndex: i,
        col: sections[i].lastColumn,
        row: preferredRow,
      );
    }
  }

  return _firstCursor(sections);
}
