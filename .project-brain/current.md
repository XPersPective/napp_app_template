# Current Architecture

## Runtime
Standalone Dart generator and installed Flutter SDK. No generated app in this repository.

## Map
tool/new_app.dart — Flutter generator, duplicated in napp-core/tool
tool/templates/main.dart.template — optional core/Pro/ads composition
tool/templates/app_test.dart.template — generated app smoke check
tool/brand — icon generator and example source
ORTAK_UYGULAMA_STANDARDI.md — retained legacy standard
PROJECT_BRAIN.md — preserved legacy document
.project-brain/migration-backup — original legacy input retained

## Generator
Sources: `tool/**`, `README.md`
VERIFIED: flutter create, conditional dependencies, manifest/Gradle edits, analyze/test/APK implemented. Template currently has ads-only compile defect, empty translations, inaccessible About/paywall, no Pro→ads sync, no monthly verification.

## Migration
VERIFIED: blank legacy goal retained; factory extension explicitly authorized by current user.