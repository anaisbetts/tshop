import 'package:flutter/foundation.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/input/shelf_focus_controller.dart';
import 'package:tshop/src/install/app_install_state.dart';
import 'package:tshop/src/install/install_queue_provider.dart';
import 'package:tshop/src/platform/app_services.dart';
import 'package:tshop/src/theme/widgets/tshop_tile.dart';

/// Focus identifier for the `Update All` action tile in `Updates available`.
const String libraryUpdateAllFocusId = 'update-all';

/// Ordered state-grouped shelves displayed on the Library screen.
enum LibraryShelfId {
  /// Active, awaiting-confirmation, and failed install tasks.
  queue('queue', 'Queue'),

  /// Installed catalog apps with a newer version available.
  updates('updates', 'Updates available'),

  /// Installed catalog apps that are up to date.
  upToDate('current', 'Up to date'),

  /// Installed catalog apps signed by a different source.
  otherSource('other', 'Other source');

  const LibraryShelfId(this.id, this.label);

  /// Stable section identifier passed to [ShelfSection].
  final String id;

  /// Shelf header label shown in `TshopFrame`.
  final String label;
}

/// One resolved app tile displayed in a Library shelf.
@immutable
final class LibraryEntryItem {
  /// Creates a [LibraryEntryItem].
  const LibraryEntryItem({
    required this.state,
    required this.categoryLabel,
    required this.unmetCapabilityLabels,
  });

  /// Full resolved storefront, device, and install-queue state.
  final ResolvedAppState state;

  /// Localized display label for the entry's category.
  final String categoryLabel;

  /// Localized labels for unmet required capabilities.
  final List<String> unmetCapabilityLabels;

  /// Underlying catalog entry.
  CatalogEntry get entry => state.entry;

  /// Resolved catalog/install status.
  AppCatalogStatus get status => state.status;

  /// Active or failed install queue task, if present.
  InstallTask? get activeTask => state.activeTask;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LibraryEntryItem &&
            other.state == state &&
            other.categoryLabel == categoryLabel &&
            listEquals(other.unmetCapabilityLabels, unmetCapabilityLabels);
  }

  @override
  int get hashCode => Object.hash(
    state,
    categoryLabel,
    Object.hashAll(unmetCapabilityLabels),
  );
}

/// One non-empty state-grouped shelf on the Library screen.
@immutable
final class LibraryShelfGroup {
  /// Creates a [LibraryShelfGroup].
  LibraryShelfGroup({
    required this.shelfId,
    required List<LibraryEntryItem> items,
    this.hasUpdateAllLead = false,
  }) : items = List<LibraryEntryItem>.unmodifiable(items);

  /// State group represented by this shelf.
  final LibraryShelfId shelfId;

  /// Ordered app entries in this shelf (excludes the `Update All` lead tile).
  final List<LibraryEntryItem> items;

  /// Whether slot `0` renders the `Update All` action tile.
  final bool hasUpdateAllLead;

  /// Shelf header title.
  String get label => shelfId.label;

  /// Number displayed next to the shelf title (does not count `Update All`).
  int get headerCount => items.length;

  /// Focusable cell identifiers in column-major order.
  List<String> get focusItemIds => <String>[
    if (hasUpdateAllLead) libraryUpdateAllFocusId,
    for (final item in items) item.entry.packageName,
  ];

  /// Converts this shelf into a [ShelfSection] for [ShelfFocusController].
  ShelfSection toShelfSection({required int rows}) {
    return ShelfSection(
      id: shelfId.id,
      itemIds: focusItemIds,
      rows: rows,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LibraryShelfGroup &&
            other.shelfId == shelfId &&
            other.hasUpdateAllLead == hasUpdateAllLead &&
            listEquals(other.items, items);
  }

  @override
  int get hashCode => Object.hash(
    shelfId,
    hasUpdateAllLead,
    Object.hashAll(items),
  );
}

/// Complete state-grouped Library shelf snapshot for rendering and navigation.
@immutable
final class LibraryViewModel {
  /// Creates a [LibraryViewModel].
  LibraryViewModel({
    required List<LibraryShelfGroup> shelves,
    required List<CatalogEntry> updateEntries,
    required Map<String, LibraryEntryItem> itemsByPackageName,
  }) : shelves = List<LibraryShelfGroup>.unmodifiable(shelves),
       updateEntries = List<CatalogEntry>.unmodifiable(updateEntries),
       itemsByPackageName = Map<String, LibraryEntryItem>.unmodifiable(
         itemsByPackageName,
       );

  /// Non-empty shelves in display order (`Queue`, `Updates available`,
  /// `Up to date`, `Other source`).
  final List<LibraryShelfGroup> shelves;

  /// Entries currently eligible for `Update All` (not already in `Queue`).
  final List<CatalogEntry> updateEntries;

  /// Lookup index from package name to its [LibraryEntryItem].
  final Map<String, LibraryEntryItem> itemsByPackageName;

  /// Whether there are no Library shelves to display.
  bool get isEmpty => shelves.isEmpty;

  /// Whether at least one shelf has items.
  bool get isNotEmpty => shelves.isNotEmpty;

  /// Looks up the focused [LibraryEntryItem] by [focusId], returning `null`
  /// for `null` or [libraryUpdateAllFocusId].
  LibraryEntryItem? itemForFocusId(String? focusId) {
    if (focusId == null || focusId == libraryUpdateAllFocusId) {
      return null;
    }
    return itemsByPackageName[focusId];
  }

  /// Builds [ShelfSection] descriptors for [ShelfFocusController].
  List<ShelfSection> toShelfSections({required int rows}) {
    return <ShelfSection>[
      for (final shelf in shelves) shelf.toShelfSection(rows: rows),
    ];
  }
}

/// Builds the state-grouped [LibraryViewModel] from the active catalog,
/// installed device packages, and install queue.
LibraryViewModel buildLibraryViewModel({
  required CatalogDocument? catalog,
  required Map<String, InstalledPackage> installedPackages,
  required InstallQueueState queue,
  required Set<String> metCapabilities,
  required DeviceInfo deviceInfo,
  String locale = defaultCatalogLocale,
}) {
  if (catalog == null) {
    return LibraryViewModel(
      shelves: const <LibraryShelfGroup>[],
      updateEntries: const <CatalogEntry>[],
      itemsByPackageName: const <String, LibraryEntryItem>{},
    );
  }

  final categoryLabels = <String, String>{
    for (final category in catalog.categories)
      category.id: category.name.resolve(locale),
  };
  final capabilityLabels = <String, String>{
    for (final tag in catalog.capabilityTags)
      tag.tag: tag.label.resolve(locale),
  };

  final queueItems = <LibraryEntryItem>[];
  final queuedPackageNames = <String>{};
  final itemsByPackageName = <String, LibraryEntryItem>{};

  for (final task in queue.orderedTasks) {
    final entry = catalog.entryByPackageName(task.packageName);
    if (entry == null) {
      continue;
    }
    final item = _resolveLibraryItem(
      entry: entry,
      installedPackages: installedPackages,
      activeTask: task,
      metCapabilities: metCapabilities,
      deviceInfo: deviceInfo,
      categoryLabels: categoryLabels,
      capabilityLabels: capabilityLabels,
    );
    queueItems.add(item);
    queuedPackageNames.add(entry.packageName);
    itemsByPackageName[entry.packageName] = item;
  }

  final updateItems = <LibraryEntryItem>[];
  final upToDateItems = <LibraryEntryItem>[];
  final otherSourceItems = <LibraryEntryItem>[];

  for (final entry in catalog.entries) {
    if (queuedPackageNames.contains(entry.packageName)) {
      continue;
    }
    final item = _resolveLibraryItem(
      entry: entry,
      installedPackages: installedPackages,
      activeTask: null,
      metCapabilities: metCapabilities,
      deviceInfo: deviceInfo,
      categoryLabels: categoryLabels,
      capabilityLabels: capabilityLabels,
    );

    switch (item.status) {
      case AppCatalogStatus.updateAvailable:
        updateItems.add(item);
        itemsByPackageName[entry.packageName] = item;
      case AppCatalogStatus.installed:
        upToDateItems.add(item);
        itemsByPackageName[entry.packageName] = item;
      case AppCatalogStatus.otherSource:
        otherSourceItems.add(item);
        itemsByPackageName[entry.packageName] = item;
      case AppCatalogStatus.available:
      case AppCatalogStatus.landing:
      case AppCatalogStatus.queued:
      case AppCatalogStatus.downloading:
      case AppCatalogStatus.verifying:
      case AppCatalogStatus.installing:
      case AppCatalogStatus.awaitingConfirm:
      case AppCatalogStatus.failed:
        break;
    }
  }

  final shelves = <LibraryShelfGroup>[
    if (queueItems.isNotEmpty)
      LibraryShelfGroup(
        shelfId: LibraryShelfId.queue,
        items: queueItems,
      ),
    if (updateItems.isNotEmpty)
      LibraryShelfGroup(
        shelfId: LibraryShelfId.updates,
        items: updateItems,
        hasUpdateAllLead: true,
      ),
    if (upToDateItems.isNotEmpty)
      LibraryShelfGroup(
        shelfId: LibraryShelfId.upToDate,
        items: upToDateItems,
      ),
    if (otherSourceItems.isNotEmpty)
      LibraryShelfGroup(
        shelfId: LibraryShelfId.otherSource,
        items: otherSourceItems,
      ),
  ];

  return LibraryViewModel(
    shelves: shelves,
    updateEntries: <CatalogEntry>[
      for (final item in updateItems) item.entry,
    ],
    itemsByPackageName: itemsByPackageName,
  );
}

/// Maps an [AppCatalogStatus] to its corresponding [TileStatus].
TileStatus libraryTileStatus(AppCatalogStatus status) {
  return switch (status) {
    AppCatalogStatus.available ||
    AppCatalogStatus.landing => TileStatus.available,
    AppCatalogStatus.installed => TileStatus.installed,
    AppCatalogStatus.updateAvailable => TileStatus.update,
    AppCatalogStatus.otherSource => TileStatus.otherSource,
    AppCatalogStatus.queued ||
    AppCatalogStatus.downloading ||
    AppCatalogStatus.verifying ||
    AppCatalogStatus.installing => TileStatus.downloading,
    AppCatalogStatus.awaitingConfirm => TileStatus.confirm,
    AppCatalogStatus.failed => TileStatus.failed,
  };
}

/// Computes the normalized progress value (`0.0..1.0`) shown on a tile's
/// bottom bar.
double libraryTileProgress(LibraryEntryItem item) {
  final task = item.activeTask;
  if (task == null) {
    return 0;
  }
  return switch (task.stage) {
    InstallTaskStage.queued => 0,
    InstallTaskStage.downloading => task.progress.clamp(0.0, 1.0),
    InstallTaskStage.verifying ||
    InstallTaskStage.installing ||
    InstallTaskStage.awaitingConfirm => 1,
    InstallTaskStage.failed => 0,
  };
}

LibraryEntryItem _resolveLibraryItem({
  required CatalogEntry entry,
  required Map<String, InstalledPackage> installedPackages,
  required InstallTask? activeTask,
  required Set<String> metCapabilities,
  required DeviceInfo deviceInfo,
  required Map<String, String> categoryLabels,
  required Map<String, String> capabilityLabels,
}) {
  final resolved = resolveAppInstallState(
    entry: entry,
    installedPackages: installedPackages,
    activeTask: activeTask,
    metCapabilities: metCapabilities,
    deviceInfo: deviceInfo,
  );
  return LibraryEntryItem(
    state: resolved,
    categoryLabel: categoryLabels[entry.category] ?? entry.category,
    unmetCapabilityLabels: <String>[
      for (final tag in resolved.unmetCapabilities)
        capabilityLabels[tag] ?? tag,
    ],
  );
}
