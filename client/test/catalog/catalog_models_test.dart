import 'package:flutter_test/flutter_test.dart';
import 'package:tshop/src/catalog/catalog_models.dart';

void main() {
  group('CatalogDocument.fromJson', () {
    test('parses thor-wayfinder rehost entry and landing entry', () {
      final catalog = CatalogDocument.fromJson(_sampleCatalogJson());

      expect(catalog.schemaVersion, 1);
      expect(catalog.generatedAt, DateTime.utc(2026, 11, 27, 0, 5));
      expect(catalog.apkBaseUrl, '/apk');
      expect(catalog.client, isNotNull);
      expect(catalog.client!.versionCode, 102);
      expect(catalog.capabilityTags.single.tag, 'dual-screen');
      expect(
        catalog.capabilityTags.single.label.resolve('fr'),
        'Double écran',
      );
      expect(catalog.categories.length, 2);
      expect(catalog.categories.first.entries, <String>[
        'dev.anais.thorwayfinder',
      ]);

      final wayfinder = catalog.entryByPackageName('dev.anais.thorwayfinder');
      expect(wayfinder, isNotNull);
      expect(wayfinder!.slug, 'thor-wayfinder');
      expect(wayfinder.rank, 1);
      expect(wayfinder.rehostMode, RehostMode.rehost);
      expect(wayfinder.landing, isNull);
      expect(wayfinder.name.resolve(), 'Thor Wayfinder');
      expect(wayfinder.summary.resolve('es'), 'Lanzador de doble pantalla');
      expect(wayfinder.description.resolve(), <String>[
        'Built specifically for the AYN Thor dual-screen handheld.',
      ]);
      expect(
        wayfinder.compatNotes?.resolve(),
        'Requires Android 13+\nWorks with gamepad navigation',
      );
      expect(wayfinder.tile.backdropColors, <String>['#1a365d', '#0b192c']);
      expect(wayfinder.tile.backdropAngle, 160.0);
      expect(wayfinder.tile.iconScale, 0.88);
      expect(wayfinder.screenshots.single.width, 1920);
      expect(wayfinder.release, isNotNull);
      expect(wayfinder.release!.versionCode, 42);
      expect(wayfinder.release!.variants.single.abis, <String>['arm64-v8a']);
      expect(wayfinder.changelogs.single.notes.resolve(), <String>[
        'Added lower-screen quick switcher.',
      ]);

      final landing = catalog.entryByPackageName('org.example.landingapp');
      expect(landing, isNotNull);
      expect(landing!.rehostMode, RehostMode.landing);
      expect(landing.landing, isNotNull);
      expect(landing.landing!.url, 'https://publisher.example/download');
      expect(
        landing.landing!.reason.resolve(),
        'Publisher distributes signed builds directly.',
      );
      expect(landing.release, isNull);
    });

    test('resolves relative asset and apkBaseUrl paths cleanly', () {
      final base = Uri.parse('http://tisiphone.snowy-sole.ts.net:8787');
      final resolved = CatalogDocument.fromJson(
        _sampleCatalogJson(),
      ).resolveUrls(base);

      expect(
        resolved.apkBaseUrl,
        'http://tisiphone.snowy-sole.ts.net:8787/apk',
      );

      final wayfinder = resolved.entryByPackageName('dev.anais.thorwayfinder')!;
      expect(
        wayfinder.tile.iconUrl,
        'http://tisiphone.snowy-sole.ts.net:8787/art/wayfinder-icon.webp',
      );
      expect(
        wayfinder.featureUrl,
        'http://tisiphone.snowy-sole.ts.net:8787/art/wayfinder-feature.webp',
      );
      expect(
        wayfinder.screenshots.single.thumbUrl,
        'http://tisiphone.snowy-sole.ts.net:8787/art/shot1-thumb.webp',
      );
      expect(
        wayfinder.screenshots.single.fullUrl,
        'http://tisiphone.snowy-sole.ts.net:8787/art/shot1-full.webp',
      );

      final landing = resolved.entryByPackageName('org.example.landingapp')!;
      expect(
        landing.tile.iconUrl,
        'https://cdn.external.example/icon.webp',
      );
      expect(landing.featureUrl, isNull);
    });

    test('apkDownloadUri builds tShop and privacyMode URLs', () {
      final catalog = CatalogDocument.fromJson(_sampleCatalogJson());
      final entry = catalog.entryByPackageName('dev.anais.thorwayfinder')!;
      final variant = entry.release!.variants.single;
      final base = Uri.parse('http://127.0.0.1:8787');

      expect(
        entry.apkDownloadUri(
          catalogBaseUrl: base,
          apkBaseUrl: '/apk',
          variant: variant,
          intent: 'install',
        ),
        Uri.parse(
          'http://127.0.0.1:8787/apk/${variant.sha256}.apk?r=install',
        ),
      );

      expect(
        entry.apkDownloadUri(
          catalogBaseUrl: base,
          apkBaseUrl: 'https://dl.tshop.example/apk',
          variant: variant,
          intent: 'update',
        ),
        Uri.parse(
          'https://dl.tshop.example/apk/${variant.sha256}.apk?r=update',
        ),
      );

      expect(
        entry.apkDownloadUri(
          catalogBaseUrl: base,
          apkBaseUrl: '/apk',
          variant: variant,
          intent: 'install',
          privacyMode: true,
        ),
        Uri.parse(variant.upstreamUrl),
      );
    });
  });

  group('LocalizedText & LocalizedStringList', () {
    test('falls back from regional tag to base language, en, then first', () {
      final text = LocalizedText(const <String, String>{
        'en': 'English',
        'es': 'Español',
      });
      expect(text.resolve('es-MX'), 'Español');
      expect(text.resolve('fr'), 'English');

      final noEnglish = LocalizedText(const <String, String>{
        'ja': '日本語',
      });
      expect(noEnglish.resolve('de'), '日本語');

      final list = LocalizedStringList(const <String, List<String>>{
        'en': <String>['First'],
        'fr': <String>['Premier'],
      });
      expect(list.resolve('fr_CA'), <String>['Premier']);
      expect(list.resolve('de'), <String>['First']);
    });
  });
}

Map<String, dynamic> _sampleCatalogJson() {
  return <String, dynamic>{
    'schemaVersion': 1,
    'generatedAt': '2026-11-27T00:05:00Z',
    'apkBaseUrl': '/apk',
    'client': <String, dynamic>{
      'versionCode': 102,
      'versionName': '1.0.2',
      'releasedAt': '2026-11-26T18:00:00Z',
      'notes': <String, dynamic>{
        'en': <String>['Improved catalog caching.'],
      },
      'sha256': '1' * 64,
      'sizeBytes': 15200000,
      'minSdk': 29,
      'upstreamUrl': 'https://github.com/anaisbetts/tshop/releases/v1.0.2.apk',
    },
    'capabilityTags': <Map<String, dynamic>>[
      <String, dynamic>{
        'tag': 'dual-screen',
        'label': <String, dynamic>{
          'en': 'Dual Screen',
          'fr': 'Double écran',
        },
      },
    ],
    'categories': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'Frontends',
        'name': <String, dynamic>{'en': 'Frontends'},
        'entries': <String>['dev.anais.thorwayfinder'],
      },
      <String, dynamic>{
        'id': 'Utilities',
        'name': <String, dynamic>{'en': 'Utilities'},
        'entries': <String>['org.example.landingapp'],
      },
    ],
    'entries': <Map<String, dynamic>>[
      <String, dynamic>{
        'packageName': 'dev.anais.thorwayfinder',
        'slug': 'thor-wayfinder',
        'rank': 1,
        'name': <String, dynamic>{'en': 'Thor Wayfinder'},
        'publisher': 'Anais Betts',
        'category': 'Frontends',
        'searchTags': <String>['launcher', 'dual-screen', 'thor'],
        'summary': <String, dynamic>{
          'en': 'Dual-screen launcher for AYN Thor',
          'es': 'Lanzador de doble pantalla',
        },
        'description': <String, dynamic>{
          'en': <String>[
            'Built specifically for the AYN Thor dual-screen handheld.',
          ],
        },
        'compatNotes': <String, dynamic>{
          'en': <String>[
            'Requires Android 13+',
            'Works with gamepad navigation',
          ],
        },
        'homepageUrl': 'https://github.com/anaisbetts/thor-wayfinder',
        'rehostMode': 'rehost',
        'landing': null,
        'allowedSigningCerts': <String>['aa:bb:cc'],
        'capabilities': <String>['dual-screen'],
        'tile': <String, dynamic>{
          'iconUrl': '/art/wayfinder-icon.webp',
          'backdropColors': <String>['#1a365d', '#0b192c'],
          'backdropAngle': 160,
          'iconScale': 0.88,
        },
        'featureUrl': '/art/wayfinder-feature.webp',
        'screenshots': <Map<String, dynamic>>[
          <String, dynamic>{
            'thumbUrl': '/art/shot1-thumb.webp',
            'fullUrl': '/art/shot1-full.webp',
            'width': 1920,
            'height': 1080,
          },
        ],
        'release': <String, dynamic>{
          'versionCode': 42,
          'versionName': '2.1.0',
          'releasedAt': '2026-11-25T10:00:00Z',
          'variantsAreUserChoice': false,
          'variants': <Map<String, dynamic>>[
            <String, dynamic>{
              'sha256': '2' * 64,
              'sizeBytes': 8400000,
              'abis': <String>['arm64-v8a'],
              'minSdk': 31,
              'targetSdk': 35,
              'label': null,
              'note': null,
              'upstreamUrl': 'https://github.com/anaisbetts/thor-wayfinder/releases/v2.1.0.apk',
            },
          ],
        },
        'changelogs': <Map<String, dynamic>>[
          <String, dynamic>{
            'versionCode': 42,
            'versionName': '2.1.0',
            'releasedAt': '2026-11-25T10:00:00Z',
            'notes': <String, dynamic>{
              'en': <String>['Added lower-screen quick switcher.'],
            },
          },
        ],
      },
      <String, dynamic>{
        'packageName': 'org.example.landingapp',
        'slug': 'landing-app',
        'rank': 2,
        'name': <String, dynamic>{'en': 'Publisher Only App'},
        'publisher': 'Example Publisher',
        'category': 'Utilities',
        'searchTags': <String>['utility'],
        'summary': <String, dynamic>{'en': 'External publisher download'},
        'description': <String, dynamic>{
          'en': <String>['Available directly from the publisher website.'],
        },
        'compatNotes': null,
        'homepageUrl': 'https://publisher.example',
        'rehostMode': 'landing',
        'landing': <String, dynamic>{
          'reason': <String, dynamic>{
            'en': 'Publisher distributes signed builds directly.',
          },
          'url': 'https://publisher.example/download',
        },
        'allowedSigningCerts': <String>[],
        'capabilities': <String>[],
        'tile': <String, dynamic>{
          'iconUrl': 'https://cdn.external.example/icon.webp',
          'backdropColors': <String>['#2d3748'],
          'backdropAngle': 90,
          'iconScale': 1.0,
        },
        'featureUrl': null,
        'screenshots': <Map<String, dynamic>>[],
        'release': null,
        'changelogs': <Map<String, dynamic>>[],
      },
    ],
  };
}
