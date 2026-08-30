# tShop

> A curated app store for Android game consoles.

tShop should feel like the Nintendo 3DS home menu built for modern Android
handhelds. You browse a grid of square tiles, open one to see proper artwork
and useful details, then install it. No hunting through GitHub releases. No
mystery manifest copied from a Discord message. No wondering whether updates
still work.

The name is an homage to the 3DS's hShop. The goal is similarly direct: make
finding and installing software on a game console pleasant.

This document defines the product. It deliberately leaves framework choices,
service design, data formats, and other implementation details for later.

## Status

tShop is at the product-definition stage. Version one will prove that a small,
carefully maintained catalog can make setting up and updating an Android
handheld better than Obtainium.

## The problem

Android game consoles have a healthy software ecosystem but no good way to
browse it.

People currently use tools such as Obtainium to follow APK releases from
GitHub and other websites. Obtainium solves part of the distribution problem,
but the experience is miserable:

- Its catalogs are uncurated JSON manifests from third-party repositories.
Users cannot easily tell who maintains a manifest, what it contains, or
whether it is current.
- Browsing amounts to scrolling through a utilitarian list. Apps have little
artwork, thin descriptions, and no sense of discovery.
- Release detection is fragile. Upstream changes, bad matching rules, and
stale metadata turn routine updates into troubleshooting.
- The user has to understand where software comes from before they can install
it. That is backwards for a store.

tShop takes responsibility for the catalog and the storefront. Users should
not need to know how an upstream project publishes releases.

## Who tShop is for

The primary audience is someone who owns an Android gaming handheld such as a
Retroid Pocket, AYN Odin, or Android-based Anbernic device. They want
emulators, games, frontends, and console utilities without treating each
installation as a research project.

Version one targets handhelds with built-in game controls and a touchscreen.
Phones and tablets may work, but they do not drive the design. Android TV and
touchless devices can follow once the handheld experience is solid.

## Product principles

### Curated means accountable

tShop has one first-party catalog. The project decides what appears in it,
verifies every entry, and owns mistakes. Users never have to choose
between anonymous sources or guess which manifest to trust.

A smaller catalog with 30 excellent entries is more useful than 300 entries
with broken links, wrong packages, and placeholder art.

### It should look like a game console

The visual reference is the Nintendo 3DS home menu, with a nod to launchers
such as iisu. Apps live in a playful grid of square tiles rather than a
settings-style list.

Good artwork is part of the product, not decoration to add later. Every entry
needs a recognizable square tile, a real description, and enough imagery to
understand the app before installing it.

### Updates must be boring

Users should be able to trust that an update belongs to the app they
installed, comes from the expected publisher, and will install. tShop absorbs
the messy work of watching upstream projects and interpreting their releases.

When an upstream release is malformed or suspicious, the catalog should keep
offering the last known-good version instead of passing the problem to every
device.

### Controllers are first-class input

Every screen and action must work with a d-pad and the standard confirm and
back buttons. Focus must remain visible, directional movement must be
predictable, and no essential control may require touch.

Touch remains fully supported. It is a second complete input method, not a
fallback for unfinished controller navigation.

### Free Software, run in public

tShop itself is Free Software. If the project grows enough to need ongoing
funding, recurring community support such as Patreon is the preferred model.

Version one does not depend on user accounts, advertising, or analytics. The
project has not yet decided whether to collect usage data. If it does, tShop
will document exactly what it collects, operate the system itself, and publish
the resulting dashboards. Data collection should never become a hidden part of
the product.

## The catalog

The tShop catalog is a maintained index of software relevant to Android game
consoles.

### What belongs in version one

- Emulators
- Game-library frontends and launchers
- Native Android ports
- Free and open-source games
- Independently distributed games whose publishers provide a legitimate APK
- Console utilities such as controller, display, and performance tools

Version one distributes APK-based applications only. Catalog entries point to
legitimate, publisher-controlled upstream releases.

### What does not belong

- Commercial APKs redistributed without the publisher's permission
- Pirated games or applications
- ROM sets
- BIOS and firmware files
- Downloads with an unclear owner or source
- Releases that cannot pass the catalog's identity and integrity checks

tShop is not a piracy tool and should not become one by accident through lax
catalog rules.

### Entry quality bar

Every published entry should have:

- A stable identity, including its Android package name and expected signing
identity
- A legitimate upstream project and download source
- A name, concise summary, full description, and category
- A recognizable square tile created from official project assets where
possible
- A larger icon or artwork for the detail view
- Screenshots that show what the software does
- Current version, release date, and changelog information when upstream
provides it
- Compatibility or setup notes when the app has console-specific caveats

Finding and preparing this material is part of the catalog pipeline. Automated
and AI-assisted tools may search an upstream repository, website, or press kit
for icons and screenshots. A human still approves what reaches the store.

The initial catalog will be seeded and maintained directly by the project.
Whether outside contributors can propose entries through a public repository
or another process is a later decision.

### Release tracking

The catalog service, not each handheld, determines the latest approved
release.

For every update, the catalog pipeline should confirm at least:

- The APK exists and can be downloaded
- Its package name matches the catalog entry
- Its version is newer than the currently approved release
- Its signing identity matches the expected publisher
- Its basic metadata can be read successfully

Only releases that pass validation enter the signed catalog. The published
entry contains the approved version and a direct download location. Every
tShop client therefore sees the same answer, and one broken upstream release
cannot break updates for the entire installed base.

The first release does not need to mirror APKs. tShop may download from the
publisher's upstream distribution while owning the metadata and validation
around it.

## The app experience

### Browse

The default screen is a dense, d-pad-friendly grid of square app tiles. The
selected tile is always obvious. Moving around the grid should feel closer to
browsing a console menu than operating a package manager.

Users can narrow the grid by category or search by app name and description.
Version one does not require a personalized home page, ratings,
recommendations, or an account.

### App details

Selecting a tile opens a dedicated detail view. This is where tShop
can use larger artwork and explain why someone might want the app.

The view should show:

- App name, larger icon or artwork, and screenshots
- Short summary and full description
- Category and relevant compatibility notes
- Latest approved version and release date
- Changelog, when available
- Upstream project or publisher
- Installed version and update status, when applicable
- One clear primary action such as Install, Update, Open, or Retry

The user should be able to move from curiosity to an install without
opening a browser.

### Library

The Library shows apps installed through tShop, their installed and
available versions, and any pending updates. It is the practical
counterpart to the browse grid.

Users can update one app or start an Update All queue. Failures must
identify the affected app and preserve the rest of the queue.

### Fresh-device setup

A common first session is a new handheld with almost no software on
it. tShop should support that session well:

1. Open tShop.
2. Browse or search the curated catalog.
3. Inspect an app and install it.
4. Repeat until the device has the desired emulators, frontend, games,
and utilities.
5. Return later to find those apps together in the Library and keep
them current.

Completing this flow should not require Obtainium, a web browser, or
knowledge of GitHub release conventions.

## Installs and updates

Version one uses Android's normal package installer. Android may still
ask the user to confirm each installation or update. tShop should make
those prompts the only manual part of the process.

When the platform supports it, tShop should remain the recognized
installer and request update ownership for apps it installed. The
exact behavior will depend on the Android version and device policy.

tShop periodically checks the approved catalog in the background. When
updates exist, it sends one useful notification rather than requiring
users to check each app. From the Library, Update All downloads and
stages the pending updates, then walks the user through any system
confirmations in a predictable queue.

The version-one promise is reliable updates, not silent updates.
Shizuku support can later remove confirmation prompts for users who
choose to configure it, but it must not be required to use the store.

## Version one

Version one includes:

- A controller-first square-tile catalog
- Search and category filtering
- Rich app detail views
- Standard Android install and update flows
- A Library with installed versions and pending updates
- Background update checks and update notifications
- An Update All queue
- A first-party catalog containing roughly 30 to 50 vetted apps
- Server-side release monitoring and validation
- Consistent artwork and useful metadata for every catalog entry

### Success criteria

Version one succeeds when a small group of Android-handheld users can:

- Set up a fresh device using only tShop for the software covered by
its catalog
- Find and understand apps without visiting their upstream websites
- Install every selected app through the store
- Receive accurate update notices and complete updates from the
Library
- Keep using the catalog for one month without catalog-caused broken
installs, mismatched packages, or stale update rules

The informal test is simpler: nobody reaches for Obtainium or a
browser, and nobody has to curse at updates.

## Not in version one

- Silent updates through Shizuku or root
- ROMs, BIOS files, firmware, or other game-content downloads
- Android TV as a first-class form factor
- Touchless-device certification
- User accounts
- Ratings and reviews
- Personalized recommendations
- Featured banners and editorial collections
- Open community submissions to the catalog

These exclusions keep the first release focused. They are not promises
that tShop will never support the feature.

## Later

### Silent updates

Optional Shizuku integration could make updates work more like a
conventional console store. Users who grant the required access could
install approved updates without repeated system prompts.

### Curated collections

The tile grid can grow editorial entry points such as "Start here on a
new Odin" or "Best couch co-op games." Collections should exist only
when the project has the time to keep them current. A visibly
abandoned storefront would undermine the trust tShop is trying to
build.

### Game content

tShop may eventually catalog legally distributable homebrew and
freeware game content. Android's storage sandbox makes this less
useful than it first appears because tShop often cannot place files
directly into another app's private configuration.

Any game-content feature needs a clear handoff into the target
emulator or frontend. Until then, applications provide more value for
less confusion.

### More devices

Android TV and touchless handhelds are natural future targets because
the core interface already supports controllers. They still need
deliberate work around screen distance, density, focus behavior, and
platform-specific installation rules.

### Community catalog work

If maintaining the catalog becomes larger than one team can handle,
the project can accept outside app proposals and metadata or artwork
fixes. First-party approval and automated validation remain
non-negotiable even if the intake process opens up.

## Open product questions

The first implementation plan should return to these questions:

- Which 30 to 50 apps make up the launch catalog?
- Which categories are useful without making the catalog feel
fragmented?
- What is the minimum screenshot requirement when an upstream project
has poor assets?
- Should tShop collect any usage data, and what user benefit would
justify it?
- What catalog contribution process makes sense after the initial
release?
- When does recurring maintenance cost justify a Patreon or similar
funding model?

