import 'package:flutter/foundation.dart';

/// Default fallback locale key required by the catalog schema.
const String defaultCatalogLocale = 'en';

/// Distribution mode for a published [CatalogEntry].
enum RehostMode {
  /// tShop mirrors verified APK artifacts directly.
  rehost('rehost'),

  /// Entry links out to the publisher's landing page instead of hosting APKs.
  landing('landing');

  const RehostMode(this.wireValue);

  /// Wire representation used in catalog JSON.
  final String wireValue;

  /// Parses a [RehostMode] from its JSON [value].
  static RehostMode fromJson(String value) {
    return switch (value) {
      'rehost' => RehostMode.rehost,
      'landing' => RehostMode.landing,
      _ => throw FormatException('Unknown rehostMode: $value'),
    };
  }
}

/// Signed `pointer.json` document referencing an immutable catalog snapshot.
@immutable
class CatalogPointer {
  /// Creates a [CatalogPointer].
  const CatalogPointer({
    required this.schemaVersion,
    required this.minClientVersionCode,
    required this.generatedAt,
    required this.generatedAtRaw,
    required this.keyId,
    required this.catalogUrl,
    required this.catalogSha256,
    required this.catalogSize,
    required this.statsUrl,
    required this.signature,
  });

  /// Parses a [CatalogPointer] from decoded JSON.
  factory CatalogPointer.fromJson(Map<String, dynamic> json) {
    final generatedAtRaw = _requireString(json, 'generatedAt');
    return CatalogPointer(
      schemaVersion: _requireInt(json, 'schemaVersion'),
      minClientVersionCode: _requireInt(json, 'minClientVersionCode'),
      generatedAt: DateTime.parse(generatedAtRaw),
      generatedAtRaw: generatedAtRaw,
      keyId: _requireString(json, 'keyId'),
      catalogUrl: _requireString(json, 'catalogUrl'),
      catalogSha256: _requireString(json, 'catalogSha256'),
      catalogSize: _requireInt(json, 'catalogSize'),
      statsUrl: _requireString(json, 'statsUrl'),
      signature: _requireString(json, 'signature'),
    );
  }

  /// Pointer schema version.
  final int schemaVersion;

  /// Minimum client `versionCode` required to accept this catalog.
  final int minClientVersionCode;

  /// Parsed UTC timestamp when this pointer was generated.
  final DateTime generatedAt;

  /// Verbatim ISO-8601 `generatedAt` string used for signature verification.
  final String generatedAtRaw;

  /// Identifier of the Ed25519 signing key.
  final String keyId;

  /// Relative or absolute URL to `catalog-<sha256>.json`.
  final String catalogUrl;

  /// Lowercase hex SHA-256 digest of the catalog JSON bytes.
  final String catalogSha256;

  /// Byte length of the catalog JSON payload.
  final int catalogSize;

  /// Public statistics URL shown in About.
  final String statsUrl;

  /// Base64-encoded Ed25519 signature over canonical pointer fields.
  final String signature;

  /// Serializes this pointer back to JSON preserving [generatedAtRaw].
  Map<String, Object> toJson() {
    return <String, Object>{
      'schemaVersion': schemaVersion,
      'minClientVersionCode': minClientVersionCode,
      'generatedAt': generatedAtRaw,
      'keyId': keyId,
      'catalogUrl': catalogUrl,
      'catalogSha256': catalogSha256,
      'catalogSize': catalogSize,
      'statsUrl': statsUrl,
      'signature': signature,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogPointer &&
            other.schemaVersion == schemaVersion &&
            other.minClientVersionCode == minClientVersionCode &&
            other.generatedAt == generatedAt &&
            other.generatedAtRaw == generatedAtRaw &&
            other.keyId == keyId &&
            other.catalogUrl == catalogUrl &&
            other.catalogSha256 == catalogSha256 &&
            other.catalogSize == catalogSize &&
            other.statsUrl == statsUrl &&
            other.signature == signature;
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    minClientVersionCode,
    generatedAt,
    generatedAtRaw,
    keyId,
    catalogUrl,
    catalogSha256,
    catalogSize,
    statsUrl,
    signature,
  );
}

/// Published immutable catalog document (`catalog-<sha256>.json`).
@immutable
class CatalogDocument {
  /// Creates a [CatalogDocument].
  CatalogDocument({
    required this.schemaVersion,
    required this.generatedAt,
    required this.apkBaseUrl,
    required List<CatalogCapabilityTag> capabilityTags,
    required List<CatalogCategoryFrame> categories,
    required List<CatalogEntry> entries,
    this.client,
  }) : capabilityTags = List<CatalogCapabilityTag>.unmodifiable(capabilityTags),
       categories = List<CatalogCategoryFrame>.unmodifiable(categories),
       entries = List<CatalogEntry>.unmodifiable(entries);

  /// Parses a [CatalogDocument] from decoded JSON.
  factory CatalogDocument.fromJson(Map<String, dynamic> json) {
    final clientJson = json['client'];
    return CatalogDocument(
      schemaVersion: _requireInt(json, 'schemaVersion'),
      generatedAt: DateTime.parse(_requireString(json, 'generatedAt')),
      apkBaseUrl: _requireString(json, 'apkBaseUrl'),
      client: clientJson is Map<String, dynamic>
          ? CatalogClientRelease.fromJson(clientJson)
          : null,
      capabilityTags: _parseObjectList(
        json['capabilityTags'],
        CatalogCapabilityTag.fromJson,
      ),
      categories: _parseObjectList(
        json['categories'],
        CatalogCategoryFrame.fromJson,
      ),
      entries: _parseObjectList(json['entries'], CatalogEntry.fromJson),
    );
  }

  /// Catalog schema version.
  final int schemaVersion;

  /// Timestamp when this catalog snapshot was generated.
  final DateTime generatedAt;

  /// Base URL for APK downloads (may be relative before [resolveUrls]).
  final String apkBaseUrl;

  /// Latest tShop self-update release metadata, if present.
  final CatalogClientRelease? client;

  /// Capability tag definitions referenced by entries.
  final List<CatalogCapabilityTag> capabilityTags;

  /// Curated category frames in display order.
  final List<CatalogCategoryFrame> categories;

  /// Published app entries in global popularity order.
  final List<CatalogEntry> entries;

  /// Looks up an entry by Android [packageName], or `null` if absent.
  CatalogEntry? entryByPackageName(String packageName) {
    for (final entry in entries) {
      if (entry.packageName == packageName) {
        return entry;
      }
    }
    return null;
  }

  /// Returns a copy with all relative asset and APK URLs resolved against
  /// [baseUrl].
  CatalogDocument resolveUrls(Uri baseUrl) {
    return CatalogDocument(
      schemaVersion: schemaVersion,
      generatedAt: generatedAt,
      apkBaseUrl: baseUrl.resolve(apkBaseUrl).toString(),
      client: client,
      capabilityTags: capabilityTags,
      categories: categories,
      entries: entries.map((entry) => entry.resolveUrls(baseUrl)).toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogDocument &&
            other.schemaVersion == schemaVersion &&
            other.generatedAt == generatedAt &&
            other.apkBaseUrl == apkBaseUrl &&
            other.client == client &&
            listEquals(other.capabilityTags, capabilityTags) &&
            listEquals(other.categories, categories) &&
            listEquals(other.entries, entries);
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    generatedAt,
    apkBaseUrl,
    client,
    Object.hashAll(capabilityTags),
    Object.hashAll(categories),
    Object.hashAll(entries),
  );
}

/// Published storefront application entry.
@immutable
class CatalogEntry {
  /// Creates a [CatalogEntry].
  CatalogEntry({
    required this.packageName,
    required this.slug,
    required this.rank,
    required this.name,
    required this.publisher,
    required this.category,
    required List<String> searchTags,
    required this.summary,
    required this.description,
    required this.homepageUrl,
    required this.rehostMode,
    required List<String> allowedSigningCerts,
    required List<String> capabilities,
    required this.tile,
    required List<CatalogScreenshot> screenshots,
    required List<CatalogChangelog> changelogs,
    this.compatNotes,
    this.landing,
    this.featureUrl,
    this.release,
  }) : searchTags = List<String>.unmodifiable(searchTags),
       allowedSigningCerts = List<String>.unmodifiable(allowedSigningCerts),
       capabilities = List<String>.unmodifiable(capabilities),
       screenshots = List<CatalogScreenshot>.unmodifiable(screenshots),
       changelogs = List<CatalogChangelog>.unmodifiable(changelogs);

  /// Parses a [CatalogEntry] from decoded JSON.
  factory CatalogEntry.fromJson(Map<String, dynamic> json) {
    final compatJson = json['compatNotes'];
    final landingJson = json['landing'];
    final releaseJson = json['release'];
    return CatalogEntry(
      packageName: _requireString(json, 'packageName'),
      slug: _requireString(json, 'slug'),
      rank: _requireInt(json, 'rank'),
      name: LocalizedText.fromJson(_requireMap(json, 'name')),
      publisher: _requireString(json, 'publisher'),
      category: _requireString(json, 'category'),
      searchTags: _parseStringList(json['searchTags']),
      summary: LocalizedText.fromJson(_requireMap(json, 'summary')),
      description: LocalizedStringList.fromJson(
        _requireMap(json, 'description'),
      ),
      compatNotes: compatJson is Map<String, dynamic>
          ? LocalizedText.fromJson(compatJson)
          : null,
      homepageUrl: _requireString(json, 'homepageUrl'),
      rehostMode: RehostMode.fromJson(_requireString(json, 'rehostMode')),
      landing: landingJson is Map<String, dynamic>
          ? CatalogLanding.fromJson(landingJson)
          : null,
      allowedSigningCerts: _parseStringList(json['allowedSigningCerts']),
      capabilities: _parseStringList(json['capabilities']),
      tile: CatalogTile.fromJson(_requireMap(json, 'tile')),
      featureUrl: json['featureUrl'] as String?,
      screenshots: _parseObjectList(
        json['screenshots'],
        CatalogScreenshot.fromJson,
      ),
      release: releaseJson is Map<String, dynamic>
          ? CatalogRelease.fromJson(releaseJson)
          : null,
      changelogs: _parseObjectList(
        json['changelogs'],
        CatalogChangelog.fromJson,
      ),
    );
  }

  /// Android application package identifier.
  final String packageName;

  /// URL-friendly catalog slug.
  final String slug;

  /// 1-based position in global popularity order.
  final int rank;

  /// Localized display name.
  final LocalizedText name;

  /// Publisher name.
  final String publisher;

  /// Category identifier (e.g. `Emulators`, `Frontends`, `Games`, `Utilities`).
  final String category;

  /// Additional search keywords.
  final List<String> searchTags;

  /// Localized one-line summary.
  final LocalizedText summary;

  /// Localized description paragraphs.
  final LocalizedStringList description;

  /// Optional localized compatibility notes.
  final LocalizedText? compatNotes;

  /// Upstream project homepage URL.
  final String homepageUrl;

  /// Whether APKs are rehosted by tShop or delegated to a publisher landing
  /// page.
  final RehostMode rehostMode;

  /// Landing page metadata when [rehostMode] is [RehostMode.landing].
  final CatalogLanding? landing;

  /// SHA-256 fingerprints of trusted publisher signing certificates.
  final List<String> allowedSigningCerts;

  /// Capability tag identifiers required or supported by this app.
  final List<String> capabilities;

  /// Live-composited tile artwork metadata.
  final CatalogTile tile;

  /// Optional feature graphic URL shown on Detail.
  final String? featureUrl;

  /// Screenshots shown on Detail.
  final List<CatalogScreenshot> screenshots;

  /// Latest approved release, if known.
  final CatalogRelease? release;

  /// Up to 5 recent release changelogs, newest first.
  final List<CatalogChangelog> changelogs;

  /// Builds the APK download URI for [variant].
  ///
  /// When [privacyMode] is `true`, returns [CatalogVariant.upstreamUrl]
  /// directly. Otherwise builds
  /// `${apkBaseUrl}/${variant.sha256}.apk?r=$intent` resolved against
  /// [catalogBaseUrl].
  Uri apkDownloadUri({
    required Uri catalogBaseUrl,
    required String apkBaseUrl,
    required CatalogVariant variant,
    required String intent,
    bool privacyMode = false,
  }) {
    if (privacyMode) {
      return catalogBaseUrl.resolve(variant.upstreamUrl);
    }
    final resolvedBase = catalogBaseUrl.resolve(apkBaseUrl);
    final basePath = resolvedBase.path.endsWith('/')
        ? resolvedBase.path
        : '${resolvedBase.path}/';
    return resolvedBase.replace(
      path: '$basePath${variant.sha256}.apk',
      queryParameters: <String, String>{'r': intent},
    );
  }

  /// Returns a copy with relative artwork URLs resolved against [baseUrl].
  CatalogEntry resolveUrls(Uri baseUrl) {
    return CatalogEntry(
      packageName: packageName,
      slug: slug,
      rank: rank,
      name: name,
      publisher: publisher,
      category: category,
      searchTags: searchTags,
      summary: summary,
      description: description,
      compatNotes: compatNotes,
      homepageUrl: homepageUrl,
      rehostMode: rehostMode,
      landing: landing,
      allowedSigningCerts: allowedSigningCerts,
      capabilities: capabilities,
      tile: tile.resolveUrls(baseUrl),
      featureUrl: featureUrl == null
          ? null
          : baseUrl.resolve(featureUrl!).toString(),
      screenshots: screenshots
          .map((shot) => shot.resolveUrls(baseUrl))
          .toList(),
      release: release,
      changelogs: changelogs,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogEntry &&
            other.packageName == packageName &&
            other.slug == slug &&
            other.rank == rank &&
            other.name == name &&
            other.publisher == publisher &&
            other.category == category &&
            listEquals(other.searchTags, searchTags) &&
            other.summary == summary &&
            other.description == description &&
            other.compatNotes == compatNotes &&
            other.homepageUrl == homepageUrl &&
            other.rehostMode == rehostMode &&
            other.landing == landing &&
            listEquals(other.allowedSigningCerts, allowedSigningCerts) &&
            listEquals(other.capabilities, capabilities) &&
            other.tile == tile &&
            other.featureUrl == featureUrl &&
            listEquals(other.screenshots, screenshots) &&
            other.release == release &&
            listEquals(other.changelogs, changelogs);
  }

  @override
  int get hashCode => Object.hash(
    packageName,
    slug,
    rank,
    name,
    publisher,
    category,
    Object.hashAll(searchTags),
    summary,
    description,
    compatNotes,
    homepageUrl,
    rehostMode,
    landing,
    Object.hashAll(allowedSigningCerts),
    Object.hashAll(capabilities),
    tile,
    featureUrl,
    Object.hashAll(screenshots),
    release,
    Object.hashAll(changelogs),
  );
}

/// Self-update metadata for the tShop client itself.
@immutable
class CatalogClientRelease {
  /// Creates a [CatalogClientRelease].
  const CatalogClientRelease({
    required this.versionCode,
    required this.versionName,
    required this.releasedAt,
    required this.notes,
    required this.sha256,
    required this.sizeBytes,
    required this.minSdk,
    required this.upstreamUrl,
  });

  /// Parses a [CatalogClientRelease] from decoded JSON.
  factory CatalogClientRelease.fromJson(Map<String, dynamic> json) {
    return CatalogClientRelease(
      versionCode: _requireInt(json, 'versionCode'),
      versionName: _requireString(json, 'versionName'),
      releasedAt: DateTime.parse(_requireString(json, 'releasedAt')),
      notes: LocalizedStringList.fromJson(_requireMap(json, 'notes')),
      sha256: _requireString(json, 'sha256'),
      sizeBytes: _requireInt(json, 'sizeBytes'),
      minSdk: _requireInt(json, 'minSdk'),
      upstreamUrl: _requireString(json, 'upstreamUrl'),
    );
  }

  /// Android versionCode for the tShop APK.
  final int versionCode;

  /// Human-readable version string.
  final String versionName;

  /// Release timestamp.
  final DateTime releasedAt;

  /// Localized release note bullets.
  final LocalizedStringList notes;

  /// Lowercase hex SHA-256 of the APK.
  final String sha256;

  /// Size of the APK in bytes.
  final int sizeBytes;

  /// Minimum supported Android SDK level.
  final int minSdk;

  /// Direct upstream APK URL used in Privacy Mode.
  final String upstreamUrl;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogClientRelease &&
            other.versionCode == versionCode &&
            other.versionName == versionName &&
            other.releasedAt == releasedAt &&
            other.notes == notes &&
            other.sha256 == sha256 &&
            other.sizeBytes == sizeBytes &&
            other.minSdk == minSdk &&
            other.upstreamUrl == upstreamUrl;
  }

  @override
  int get hashCode => Object.hash(
    versionCode,
    versionName,
    releasedAt,
    notes,
    sha256,
    sizeBytes,
    minSdk,
    upstreamUrl,
  );
}

/// Capability tag label definition.
@immutable
class CatalogCapabilityTag {
  /// Creates a [CatalogCapabilityTag].
  const CatalogCapabilityTag({required this.tag, required this.label});

  /// Parses a [CatalogCapabilityTag] from decoded JSON.
  factory CatalogCapabilityTag.fromJson(Map<String, dynamic> json) {
    return CatalogCapabilityTag(
      tag: _requireString(json, 'tag'),
      label: LocalizedText.fromJson(_requireMap(json, 'label')),
    );
  }

  /// Machine-readable capability tag identifier.
  final String tag;

  /// Localized human-readable label.
  final LocalizedText label;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogCapabilityTag &&
            other.tag == tag &&
            other.label == label;
  }

  @override
  int get hashCode => Object.hash(tag, label);
}

/// Ordered category shelf on the Browse screen.
@immutable
class CatalogCategoryFrame {
  /// Creates a [CatalogCategoryFrame].
  CatalogCategoryFrame({
    required this.id,
    required this.name,
    required List<String> entries,
  }) : entries = List<String>.unmodifiable(entries);

  /// Parses a [CatalogCategoryFrame] from decoded JSON.
  factory CatalogCategoryFrame.fromJson(Map<String, dynamic> json) {
    return CatalogCategoryFrame(
      id: _requireString(json, 'id'),
      name: LocalizedText.fromJson(_requireMap(json, 'name')),
      entries: _parseStringList(json['entries']),
    );
  }

  /// Category identifier.
  final String id;

  /// Localized display name for the category.
  final LocalizedText name;

  /// Package names belonging to this category in display order.
  final List<String> entries;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogCategoryFrame &&
            other.id == id &&
            other.name == name &&
            listEquals(other.entries, entries);
  }

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(entries));
}

/// Landing-page metadata for entries distributed directly by their publisher.
@immutable
class CatalogLanding {
  /// Creates a [CatalogLanding].
  const CatalogLanding({required this.reason, required this.url});

  /// Parses a [CatalogLanding] from decoded JSON.
  factory CatalogLanding.fromJson(Map<String, dynamic> json) {
    return CatalogLanding(
      reason: LocalizedText.fromJson(_requireMap(json, 'reason')),
      url: _requireString(json, 'url'),
    );
  }

  /// Localized explanation of why the app opens the publisher page.
  final LocalizedText reason;

  /// External publisher download URL.
  final String url;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogLanding && other.reason == reason && other.url == url;
  }

  @override
  int get hashCode => Object.hash(reason, url);
}

/// Live-composited storefront tile styling metadata.
@immutable
class CatalogTile {
  /// Creates a [CatalogTile].
  CatalogTile({
    required this.iconUrl,
    required List<String> backdropColors,
    required this.backdropAngle,
    required this.iconScale,
  }) : backdropColors = List<String>.unmodifiable(backdropColors);

  /// Parses a [CatalogTile] from decoded JSON.
  factory CatalogTile.fromJson(Map<String, dynamic> json) {
    return CatalogTile(
      iconUrl: _requireString(json, 'iconUrl'),
      backdropColors: _parseStringList(json['backdropColors']),
      backdropAngle: _requireDouble(json, 'backdropAngle'),
      iconScale: _requireDouble(json, 'iconScale'),
    );
  }

  /// Relative or absolute icon WebP URL.
  final String iconUrl;

  /// One or two hex color strings defining the tile backdrop gradient.
  final List<String> backdropColors;

  /// Gradient angle in degrees.
  final double backdropAngle;

  /// Icon scale factor inside the tile square.
  final double iconScale;

  /// Returns a copy with [iconUrl] resolved against [baseUrl].
  CatalogTile resolveUrls(Uri baseUrl) {
    return CatalogTile(
      iconUrl: baseUrl.resolve(iconUrl).toString(),
      backdropColors: backdropColors,
      backdropAngle: backdropAngle,
      iconScale: iconScale,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogTile &&
            other.iconUrl == iconUrl &&
            listEquals(other.backdropColors, backdropColors) &&
            other.backdropAngle == backdropAngle &&
            other.iconScale == iconScale;
  }

  @override
  int get hashCode => Object.hash(
    iconUrl,
    Object.hashAll(backdropColors),
    backdropAngle,
    iconScale,
  );
}

/// Screenshot asset metadata for a [CatalogEntry].
@immutable
class CatalogScreenshot {
  /// Creates a [CatalogScreenshot].
  const CatalogScreenshot({
    required this.thumbUrl,
    required this.fullUrl,
    required this.width,
    required this.height,
  });

  /// Parses a [CatalogScreenshot] from decoded JSON.
  factory CatalogScreenshot.fromJson(Map<String, dynamic> json) {
    return CatalogScreenshot(
      thumbUrl: _requireString(json, 'thumbUrl'),
      fullUrl: _requireString(json, 'fullUrl'),
      width: _requireInt(json, 'width'),
      height: _requireInt(json, 'height'),
    );
  }

  /// Thumbnail WebP URL.
  final String thumbUrl;

  /// Full-resolution WebP URL.
  final String fullUrl;

  /// Pixel width of the full screenshot.
  final int width;

  /// Pixel height of the full screenshot.
  final int height;

  /// Returns a copy with [thumbUrl] and [fullUrl] resolved against [baseUrl].
  CatalogScreenshot resolveUrls(Uri baseUrl) {
    return CatalogScreenshot(
      thumbUrl: baseUrl.resolve(thumbUrl).toString(),
      fullUrl: baseUrl.resolve(fullUrl).toString(),
      width: width,
      height: height,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogScreenshot &&
            other.thumbUrl == thumbUrl &&
            other.fullUrl == fullUrl &&
            other.width == width &&
            other.height == height;
  }

  @override
  int get hashCode => Object.hash(thumbUrl, fullUrl, width, height);
}

/// Latest approved release for a [CatalogEntry].
@immutable
class CatalogRelease {
  /// Creates a [CatalogRelease].
  CatalogRelease({
    required this.versionName,
    required this.releasedAt,
    required this.variantsAreUserChoice,
    required List<CatalogVariant> variants,
    this.versionCode,
  }) : variants = List<CatalogVariant>.unmodifiable(variants);

  /// Parses a [CatalogRelease] from decoded JSON.
  factory CatalogRelease.fromJson(Map<String, dynamic> json) {
    final rawCode = json['versionCode'];
    return CatalogRelease(
      versionCode: rawCode is num ? rawCode.toInt() : null,
      versionName: _requireString(json, 'versionName'),
      releasedAt: DateTime.parse(_requireString(json, 'releasedAt')),
      variantsAreUserChoice: _requireBool(json, 'variantsAreUserChoice'),
      variants: _parseObjectList(json['variants'], CatalogVariant.fromJson),
    );
  }

  /// Android versionCode (`null` for metadata-only landing releases).
  final int? versionCode;

  /// Display version name.
  final String versionName;

  /// Release timestamp.
  final DateTime releasedAt;

  /// Whether the user must choose between [variants] manually.
  final bool variantsAreUserChoice;

  /// Installable APK variants for this release.
  final List<CatalogVariant> variants;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogRelease &&
            other.versionCode == versionCode &&
            other.versionName == versionName &&
            other.releasedAt == releasedAt &&
            other.variantsAreUserChoice == variantsAreUserChoice &&
            listEquals(other.variants, variants);
  }

  @override
  int get hashCode => Object.hash(
    versionCode,
    versionName,
    releasedAt,
    variantsAreUserChoice,
    Object.hashAll(variants),
  );
}

/// Installable APK variant within a [CatalogRelease].
@immutable
class CatalogVariant {
  /// Creates a [CatalogVariant].
  CatalogVariant({
    required this.sha256,
    required this.sizeBytes,
    required List<String> abis,
    required this.minSdk,
    required this.targetSdk,
    required this.upstreamUrl,
    this.label,
    this.note,
  }) : abis = List<String>.unmodifiable(abis);

  /// Parses a [CatalogVariant] from decoded JSON.
  factory CatalogVariant.fromJson(Map<String, dynamic> json) {
    final labelJson = json['label'];
    final noteJson = json['note'];
    return CatalogVariant(
      sha256: _requireString(json, 'sha256'),
      sizeBytes: _requireInt(json, 'sizeBytes'),
      abis: _parseStringList(json['abis']),
      minSdk: _requireInt(json, 'minSdk'),
      targetSdk: _requireInt(json, 'targetSdk'),
      label: labelJson is Map<String, dynamic>
          ? LocalizedText.fromJson(labelJson)
          : null,
      note: noteJson is Map<String, dynamic>
          ? LocalizedText.fromJson(noteJson)
          : null,
      upstreamUrl: _requireString(json, 'upstreamUrl'),
    );
  }

  /// Lowercase hex SHA-256 of the APK.
  final String sha256;

  /// APK file size in bytes.
  final int sizeBytes;

  /// Supported CPU ABIs (empty means architecture-independent).
  final List<String> abis;

  /// Minimum supported Android SDK level.
  final int minSdk;

  /// Target Android SDK level.
  final int targetSdk;

  /// Optional localized variant label shown in the variant picker.
  final LocalizedText? label;

  /// Optional localized variant note shown in the variant picker.
  final LocalizedText? note;

  /// Direct upstream URL used when Privacy Mode is enabled.
  final String upstreamUrl;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogVariant &&
            other.sha256 == sha256 &&
            other.sizeBytes == sizeBytes &&
            listEquals(other.abis, abis) &&
            other.minSdk == minSdk &&
            other.targetSdk == targetSdk &&
            other.label == label &&
            other.note == note &&
            other.upstreamUrl == upstreamUrl;
  }

  @override
  int get hashCode => Object.hash(
    sha256,
    sizeBytes,
    Object.hashAll(abis),
    minSdk,
    targetSdk,
    label,
    note,
    upstreamUrl,
  );
}

/// Historical changelog entry for a [CatalogEntry].
@immutable
class CatalogChangelog {
  /// Creates a [CatalogChangelog].
  const CatalogChangelog({
    required this.versionName,
    required this.releasedAt,
    required this.notes,
    this.versionCode,
  });

  /// Parses a [CatalogChangelog] from decoded JSON.
  factory CatalogChangelog.fromJson(Map<String, dynamic> json) {
    final rawCode = json['versionCode'];
    return CatalogChangelog(
      versionCode: rawCode is num ? rawCode.toInt() : null,
      versionName: _requireString(json, 'versionName'),
      releasedAt: DateTime.parse(_requireString(json, 'releasedAt')),
      notes: LocalizedStringList.fromJson(_requireMap(json, 'notes')),
    );
  }

  /// Optional Android versionCode for this release.
  final int? versionCode;

  /// Human-readable version string.
  final String versionName;

  /// Release timestamp.
  final DateTime releasedAt;

  /// Localized bullet points describing changes.
  final LocalizedStringList notes;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CatalogChangelog &&
            other.versionCode == versionCode &&
            other.versionName == versionName &&
            other.releasedAt == releasedAt &&
            other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(versionCode, versionName, releasedAt, notes);
}

/// Map of BCP-47 locale tags to localized strings.
@immutable
class LocalizedText {
  /// Creates a [LocalizedText] from [values].
  LocalizedText(Map<String, String> values)
    : values = Map<String, String>.unmodifiable(values);

  /// Parses a [LocalizedText] from decoded JSON.
  ///
  /// Accepts string values as well as lists of strings (joined with newlines)
  /// so fields such as `compatNotes` remain forward-compatible with array
  /// payloads.
  factory LocalizedText.fromJson(Map<String, dynamic> json) {
    final parsed = <String, String>{};
    for (final entry in json.entries) {
      final raw = entry.value;
      if (raw is String) {
        parsed[entry.key] = raw;
      } else if (raw is List<dynamic>) {
        parsed[entry.key] = raw.map((item) => item.toString()).join('\n');
      } else if (raw != null) {
        throw FormatException(
          'Expected String or List<String> for locale "${entry.key}", '
          'got ${raw.runtimeType}.',
        );
      }
    }
    return LocalizedText(parsed);
  }

  /// Unmodifiable locale-to-text mapping.
  final Map<String, String> values;

  /// Resolves the localized string for [locale], falling back to its base
  /// language tag, then `'en'`, then the first available value.
  String resolve([String locale = defaultCatalogLocale]) {
    final exact = values[locale];
    if (exact != null) {
      return exact;
    }
    final base = _baseLanguageTag(locale);
    if (base != null && values.containsKey(base)) {
      return values[base]!;
    }
    final english = values[defaultCatalogLocale];
    if (english != null) {
      return english;
    }
    return values.isEmpty ? '' : values.values.first;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LocalizedText && mapEquals(other.values, values);
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}

/// Map of BCP-47 locale tags to localized string lists (paragraphs or bullets).
@immutable
class LocalizedStringList {
  /// Creates a [LocalizedStringList] from [values].
  LocalizedStringList(Map<String, List<String>> values)
    : values = Map<String, List<String>>.unmodifiable(<String, List<String>>{
        for (final entry in values.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      });

  /// Parses a [LocalizedStringList] from decoded JSON.
  factory LocalizedStringList.fromJson(Map<String, dynamic> json) {
    final parsed = <String, List<String>>{};
    for (final entry in json.entries) {
      final raw = entry.value;
      if (raw is List<dynamic>) {
        parsed[entry.key] = raw.map((item) => item.toString()).toList();
      } else if (raw is String) {
        parsed[entry.key] = <String>[raw];
      } else if (raw != null) {
        throw FormatException(
          'Expected List<String> for locale "${entry.key}", '
          'got ${raw.runtimeType}.',
        );
      }
    }
    return LocalizedStringList(parsed);
  }

  /// Unmodifiable locale-to-list mapping.
  final Map<String, List<String>> values;

  /// Resolves the localized list for [locale], falling back to its base
  /// language tag, then `'en'`, then the first available value.
  List<String> resolve([String locale = defaultCatalogLocale]) {
    final exact = values[locale];
    if (exact != null) {
      return exact;
    }
    final base = _baseLanguageTag(locale);
    if (base != null && values.containsKey(base)) {
      return values[base]!;
    }
    final english = values[defaultCatalogLocale];
    if (english != null) {
      return english;
    }
    return values.isEmpty ? const <String>[] : values.values.first;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! LocalizedStringList || other.values.length != values.length) {
      return false;
    }
    for (final entry in values.entries) {
      final otherList = other.values[entry.key];
      if (otherList == null || !listEquals(otherList, entry.value)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map(
      (entry) => Object.hash(entry.key, Object.hashAll(entry.value)),
    ),
  );
}

String? _baseLanguageTag(String locale) {
  final separatorIndex = locale.indexOf(RegExp('[-_]'));
  if (separatorIndex <= 0) {
    return null;
  }
  return locale.substring(0, separatorIndex);
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Missing or invalid String field "$key".');
}

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num && value == value.toInt()) {
    return value.toInt();
  }
  throw FormatException('Missing or invalid int field "$key".');
}

double _requireDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Missing or invalid num field "$key".');
}

bool _requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Missing or invalid bool field "$key".');
}

Map<String, dynamic> _requireMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('Missing or invalid object field "$key".');
}

List<String> _parseStringList(Object? value) {
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<dynamic>) {
    throw FormatException('Expected List<String>, got ${value.runtimeType}.');
  }
  return value.map((item) => item.toString()).toList();
}

List<T> _parseObjectList<T>(
  Object? value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value == null) {
    return <T>[];
  }
  if (value is! List<dynamic>) {
    throw FormatException('Expected List<Object>, got ${value.runtimeType}.');
  }
  return value.map((item) {
    if (item is! Map<String, dynamic>) {
      throw FormatException(
        'Expected JSON object in list, got ${item.runtimeType}.',
      );
    }
    return fromJson(item);
  }).toList();
}
