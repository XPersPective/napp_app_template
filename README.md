# napp_app_template

Existing CrazyPenguin Flutter starter, repaired and locally verified for AI App Factory.
Keep this repository as a template; generate only in a new copy. Existing lib,
pubspec.yaml or ios, and any Android content beyond the tracked regular
key.properties.example file, is refused before mutation, even --force.

Run in the new copy:

```text
dart run tool/new_app.dart --name "App Name" --package com.crazypenguin.myapp --ads yes --pro both --data local --kit-path D:/repositories/napp-core --skip-build
```

Options:
- --pro no|yes|lifetime|monthly|both (yes remains lifetime; monthly+lifetime aliases both).
- --ads yes|no; --banner yes|no defaults to ads; --rewarded yes|no defaults to ads+Pro.
- --app-open yes|no defaults OFF. Native loading waits callback up to four seconds.
- --interstitial no defaults OFF. yes is BLOCKED until the product has a genuine
  natural pause; then integrate installed InterstitialAdManager in app code.
- --other-apps yes|no defaults yes; catalog filters by actual native store.
- --source-icon uses the existing icon/splash generator (installed Pillow required).
- --kit-path uses the repaired local shared packages. Remote-only release refs need
  newly published immutable package tags; this installation never pushes/tags.
- --skip-build explicitly skips APK, for tests; default still runs APK release build.
  No Android license is accepted automatically; iOS requires macOS/Xcode.

Actual core translations, locale/theme settings, About/privacy/licenses and discover
navigation are connected. Premium state loads before SDK startup; consent+SDK are
awaited; policy follows entitlement changes. Expiring temporary Pro reloads banner/
rewarded and never opens a mid-session app-open. All actual ad state changes persist.
Free/all-optional-off excludes ad and billing SDKs, including transitive pubspec.lock.

Monthly/both generate real SDK SKU paths and truthful plan choice, but no fake verifier.
Purchase/query remain fail closed until a trusted SubscriptionVerifier is supplied.
BLOCKED production: store products/backend/account checks and live sandbox
renewal/expiry/grace/revocation/refund/restore. See napp_pro README. Product-specific
privacy/terms/contact/source/branding remain app author inputs; example URLs and
default Flutter splash without --source-icon are never production-ready claims.

Checks:
```text
dart analyze tool
dart run tool/check_template.dart
dart run tool/check_template.dart --kit-path D:/repositories/napp-core --output <new-empty-path>
```
Last command creates seven isolated actual Flutter apps: free, ads_only, lifetime,
lifetime_ads, monthly, both_ads, all_optional_off. It runs generator, fatal analyze,
phone/tablet/landscape and text-scale 1/1.3/2 light/dark navigation tests, SDK exclusion
and mutation-free rerun guards. APK and real-device visual/store QA are separate gates.
tool/new_app.dart, templates and check_template.dart are synchronized in napp-core.
Legacy PROJECT_BRAIN.md and migration-backup are preserved; .project-brain is canonical.

License remains GPL-3.0. Existing standard retained; explicitly requested optional
monthly is an authorized extension of its legacy no-subscription restriction.