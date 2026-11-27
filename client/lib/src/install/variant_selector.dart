import 'package:flutter/foundation.dart';
import 'package:tshop/src/catalog/catalog_models.dart';
import 'package:tshop/src/platform/app_services.dart';

/// Result of matching a [CatalogRelease]'s variants against a [DeviceInfo].
@immutable
final class VariantSelection {
  /// Creates a [VariantSelection].
  VariantSelection({
    required List<CatalogVariant> compatibleVariants,
    required this.bestVariant,
    required this.needsUserChoice,
  }) : compatibleVariants = List<CatalogVariant>.unmodifiable(
         compatibleVariants,
       );

  /// Compatible variants ordered by device ABI preference, preserving catalog
  /// order for ties.
  final List<CatalogVariant> compatibleVariants;

  /// Automatically selected best variant, or `null` if none are compatible.
  final CatalogVariant? bestVariant;

  /// Whether the UI must prompt the user to pick from [compatibleVariants].
  final bool needsUserChoice;

  /// Whether at least one compatible variant exists for this device.
  bool get hasCompatibleVariant => bestVariant != null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VariantSelection &&
            listEquals(other.compatibleVariants, compatibleVariants) &&
            other.bestVariant == bestVariant &&
            other.needsUserChoice == needsUserChoice;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(compatibleVariants),
    bestVariant,
    needsUserChoice,
  );
}

/// Evaluates [release] against [device] and returns the compatible variants,
/// automatic best pick, and whether a user-choice dialog is required.
VariantSelection resolveVariantSelection(
  CatalogRelease release,
  DeviceInfo device,
) {
  final compatible = selectCompatibleVariants(release, device);
  return VariantSelection(
    compatibleVariants: compatible,
    bestVariant: compatible.isEmpty ? null : compatible.first,
    needsUserChoice: release.variantsAreUserChoice && compatible.length > 1,
  );
}

/// Returns the variants of [release] compatible with [device], ordered by ABI
/// priority while preserving catalog order on ties.
///
/// When `device.sdkInt <= 0` (web demo / non-Android stub), SDK filtering is
/// bypassed; when `device.supportedAbis` is empty, ABI filtering is also
/// bypassed so web builds can display release size and metadata cleanly.
List<CatalogVariant> selectCompatibleVariants(
  CatalogRelease release,
  DeviceInfo device,
) {
  final normalizedDeviceAbis = <String>[
    for (final abi in device.supportedAbis) abi.trim().toLowerCase(),
  ];

  final scored = <_ScoredVariant>[];
  for (var index = 0; index < release.variants.length; index++) {
    final variant = release.variants[index];
    if (device.sdkInt > 0 && variant.minSdk > device.sdkInt) {
      continue;
    }

    final abiPriority = _abiPriority(variant.abis, normalizedDeviceAbis);
    if (abiPriority == null) {
      continue;
    }

    scored.add(
      _ScoredVariant(
        variant: variant,
        abiPriority: abiPriority,
        originalIndex: index,
      ),
    );
  }

  scored.sort((a, b) {
    final byAbi = a.abiPriority.compareTo(b.abiPriority);
    if (byAbi != 0) {
      return byAbi;
    }
    return a.originalIndex.compareTo(b.originalIndex);
  });

  return List<CatalogVariant>.unmodifiable(<CatalogVariant>[
    for (final item in scored) item.variant,
  ]);
}

/// Picks the highest-priority compatible variant for [device], or `null` if no
/// variant in [release] is compatible.
CatalogVariant? pickBestVariant(CatalogRelease release, DeviceInfo device) {
  final compatible = selectCompatibleVariants(release, device);
  return compatible.isEmpty ? null : compatible.first;
}

/// Returns `true` when [release] explicitly marks its variants as a user choice
/// and more than one variant is compatible with [device].
bool needsUserChoice(CatalogRelease release, DeviceInfo device) {
  if (!release.variantsAreUserChoice) {
    return false;
  }
  return selectCompatibleVariants(release, device).length > 1;
}

final class _ScoredVariant {
  const _ScoredVariant({
    required this.variant,
    required this.abiPriority,
    required this.originalIndex,
  });

  final CatalogVariant variant;
  final int abiPriority;
  final int originalIndex;
}

int? _abiPriority(List<String> variantAbis, List<String> normalizedDeviceAbis) {
  if (normalizedDeviceAbis.isEmpty) {
    return 0;
  }
  if (variantAbis.isEmpty) {
    // Universal APKs match every device, ranked after exact ABI matches.
    return normalizedDeviceAbis.length;
  }

  final normalizedVariantAbis = <String>{
    for (final abi in variantAbis) abi.trim().toLowerCase(),
  };

  for (var i = 0; i < normalizedDeviceAbis.length; i++) {
    if (normalizedVariantAbis.contains(normalizedDeviceAbis[i])) {
      return i;
    }
  }
  return null;
}
