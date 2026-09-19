// Yeni uygulama kurulum betiği — napp_app_template deposunda çalışır.
//
// Kullanım:
//   dart run tool/new_app.dart \
//     --name "Uygulama Adı" --package com.crazypenguin.uygulama \
//     --ads yes --pro yes --data local \
//     [--source-icon brand/icon_1024.png] [--kit-ref core-v1.0.0]
//     [--kit-path D:/repositories/napp-core]
//
// Idempotent çalışır; var olan bir dosyanın üzerine yazmadan önce sorar
// (--force ile sorulmadan yazar).
import 'dart:io';

const _testAdmobAppIdAndroid = 'ca-app-pub-3940256099942544~3347511713';
const _testAdmobAppIdIos = 'ca-app-pub-3940256099942544~1458002511';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  _section('napp kurulum: ${options.name}');
  stdout.writeln(
      'ads=${options.ads} pro=${options.pro} data=${options.dataLabel}');

  await _run('flutter', [
    'create',
    '--org',
    options.org,
    '--project-name',
    options.projectName,
    '--platforms',
    'android,ios',
    '.',
  ]);

  _androidManifest(options);
  _gradleRelease(options);
  _iosPlist(options);
  _writeExampleFiles(options);
  _pubspec(options);
  _projectBrain(options);
  _checkStandardDoc();

  if (options.sourceIcon != null) {
    await _run('python', [
      'tool/brand/generate_icons.py',
      '--source',
      options.sourceIcon!,
      '--app-root',
      '.',
      '--background',
      '#0B3D66',
    ]);
  }

  await _run('flutter', ['pub', 'get']);
  await _run('flutter', ['analyze']);
  await _run('flutter', ['test']);
  await _run('flutter', ['build', 'apk', '--release']);

  _section('KURULUM TAMAM');
  stdout.writeln('Şimdi: 1) PROJECT_BRAIN.md bölüm 0 tablosunu kontrol et, '
      '2) gizlilik politikası bağlantısını doldur, '
      '3) mağazada ürün kimliğini oluştur: ${options.productId}');
}

class _Options {
  _Options({
    required this.name,
    required this.packageName,
    required this.ads,
    required this.pro,
    required this.dataCloud,
    required this.sourceIcon,
    required this.kitRef,
    required this.kitPath,
    required this.force,
  });

  final String name;
  final String packageName;
  final bool ads;
  final bool pro;
  final bool dataCloud;
  final String? sourceIcon;
  final String kitRef;
  final String? kitPath;
  final bool force;

  String get dataLabel => dataCloud ? 'BULUT' : 'YEREL';

  String get org {
    final parts = packageName.split('.');
    return parts.sublist(0, parts.length - 1).join('.');
  }

  String get projectName => packageName.split('.').last;
  String get productId => '${projectName}_pro_lifetime';

  static _Options parse(List<String> args) {
    String value(String flag) {
      final index = args.indexOf(flag);
      if (index < 0 || index + 1 >= args.length) {
        throw UsageException('$flag değeri eksik');
      }
      return args[index + 1];
    }

    final name = value('--name');
    final packageName = value('--package');
    final ads = value('--ads').toLowerCase() == 'yes';
    final pro = value('--pro').toLowerCase() == 'yes';
    final dataCloud = value('--data').toLowerCase() == 'cloud';
    final sourceIcon =
        args.contains('--source-icon') ? value('--source-icon') : null;
    final kitRef =
        args.contains('--kit-ref') ? value('--kit-ref') : 'core-v1.0.0';
    final kitPath =
        args.contains('--kit-path') ? value('--kit-path') : null;
    final force = args.contains('--force');

    if (!RegExp(r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$').hasMatch(packageName)) {
      throw UsageException('geçersiz --package: $packageName');
    }
    return _Options(
      name: name,
      packageName: packageName,
      ads: ads,
      pro: pro,
      dataCloud: dataCloud,
      sourceIcon: sourceIcon,
      kitRef: kitRef,
      kitPath: kitPath,
      force: force,
    );
  }
}

class UsageException implements Exception {
  UsageException(this.message);

  final String message;

  @override
  String toString() => message;
}

void _section(String title) {
  stdout.writeln('');
  stdout.writeln('=== $title ===');
}

void _writeFile(String path, String content, {required bool force}) {
  final file = File(path);
  if (file.existsSync() && !force) {
    stdout.write('$path zaten var. Üzerine yazılsın mı? [y/N] ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    if (answer != 'y') {
      stdout.writeln('atlandı: $path');
      return;
    }
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  stdout.writeln('yazıldı: $path');
}

Future<void> _run(String executable, List<String> arguments) async {
  // Windows'ta Process.start PATH uzantılarını çözümlemez.
  final exe = Platform.isWindows && executable == 'flutter'
      ? 'flutter.bat'
      : executable;
  _section('$exe ${arguments.first} …');
  final process = await Process.start(
    exe,
    arguments,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    throw StateError('$executable ${arguments.join(' ')} => exit $code');
  }
}

void _androidManifest(_Options o) {
  final path = 'android/app/src/main/AndroidManifest.xml';
  var manifest = File(path).readAsStringSync();

  if (o.ads) {
    // Gerçek kimlik derlemede ${admobAppId} ile gelir (key.properties);
    // dosya yoksa build.gradle.kts Google test kimliğine düşer.
    manifest = manifest.replaceFirst(
      '</application>',
      '        <meta-data\n'
      '            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
      '            android:value="\${admobAppId}" />\n'
      '    </application>',
    );
  }
  // Yalnızca HTTPS (1.4).
  manifest = manifest.replaceFirst(
    '<application',
    '<application\n        android:usesCleartextTraffic="false"',
  );
  // Yedekleme kuralları (1.4): yalnızca güvenli ayarlar yedeklenir.
  manifest = manifest.replaceFirst(
    '<application',
    '<application\n'
    '        android:dataExtractionRules="@xml/data_extraction_rules"\n'
    '        android:fullBackupContent="@xml/backup_rules"',
  );
  File(path).writeAsStringSync(manifest);
  stdout.writeln('güncellendi: $path');

  const rules =
      'android/app/src/main/res/xml/data_extraction_rules.xml';
  _writeFile(
    rules,
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<data-extraction-rules>\n'
    '    <cloud-backup>\n'
    '        <exclude domain="sharedpref" path="FlutterSecureStorage"/>\n'
    '    </cloud-backup>\n'
    '    <device-transfer>\n'
    '        <exclude domain="sharedpref" path="FlutterSecureStorage"/>\n'
    '    </device-transfer>\n'
    '</data-extraction-rules>\n',
    force: o.force,
  );
  _writeFile(
    'android/app/src/main/res/xml/backup_rules.xml',
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<full-backup-content>\n'
    '    <exclude domain="sharedpref" path="FlutterSecureStorage"/>\n'
    '</full-backup-content>\n',
    force: o.force,
  );
}

void _gradleRelease(_Options o) {
  final path = 'android/app/build.gradle.kts';
  var gradle = File(path).readAsStringSync();

  // key.properties okuma kodu (imza + admobAppId; dosya yoksa test kimliği).
  gradle = gradle.replaceFirst(
    'android {',
    'import java.util.Properties\n'
    '\n'
    'val keystoreProperties = Properties().apply {\n'
    '    val file = rootProject.file("key.properties")\n'
    '    if (file.exists()) file.inputStream().use { load(it) }\n'
    '}\n'
    'val admobAppId = keystoreProperties.getProperty(\n'
    '    "admobAppId",\n'
    '    "$_testAdmobAppIdAndroid",\n'
    ')\n'
    '\n'
    'android {',
  );

  // Sürüm derlemesi: R8 küçültme + keep kuralları + key.properties imzası.
  gradle = gradle.replaceFirst(
    '        release {',
    '        release {\n'
    '            isMinifyEnabled = true\n'
    '            isShrinkResources = true\n'
    '            proguardFiles(\n'
    '                getDefaultProguardFile("proguard-android-optimize.txt"),\n'
    '                "proguard-rules.pro",\n'
    '            )',
  );

  if (o.ads) {
    gradle = gradle.replaceFirst(
      'signingConfig = signingConfigs.getByName("debug")',
      'resValue("string", "admobAppId", admobAppId)\n'
      '            signingConfig = signingConfigs.getByName("debug")',
    );
  }

  File(path).writeAsStringSync(gradle);
  stdout.writeln('güncellendi: $path');

  _writeFile(
    'android/app/proguard-rules.pro',
    "# WorkManager'ın Room veritabanı R8 tarafından silinmesin\n"
    '# (ORTAK_UYGULAMA_STANDARDI.md 8).\n'
    '-keep class androidx.work.impl.WorkDatabase { *; }\n'
    '-keep class androidx.work.impl.WorkDatabase_Impl { *; }\n'
    '-keep class androidx.work.impl.model.** { *; }\n'
    '-keep class * extends androidx.work.ListenableWorker { *; }\n'
    '-keep class androidx.room.** { *; }\n',
    force: o.force,
  );
}

void _iosPlist(_Options o) {
  final path = 'ios/Runner/Info.plist';
  var plist = File(path).readAsStringSync();
  if (o.ads) {
    plist = plist.replaceFirst(
      '<dict>',
      '<dict>\n'
      '\t<key>GADApplicationIdentifier</key>\n'
      '\t<string>\$(ADMOB_APP_ID)</string>',
    );
    File(path).writeAsStringSync(plist);
    stdout.writeln('güncellendi: $path');
    // xcconfig gitignore'dadır; geliştirici gerçek kimliği girer.
    // Varsayılan: Google test kimliği.
    _writeFile(
      'ios/Flutter/AdsConfig.xcconfig',
      'ADMOB_APP_ID = $_testAdmobAppIdIos\n',
      force: o.force,
    );
  }
}

void _pubspec(_Options o) {
  final path = 'pubspec.yaml';
  var pubspec = File(path).readAsStringSync();
  String dep(String pkg, String ref) {
    if (o.kitPath != null) {
      return '  $pkg:\n'
          '    path: ${o.kitPath}/packages/$pkg\n';
    }
    return '  $pkg:\n'
        '    git:\n'
        '      url: https://github.com/XPersPective/napp_kit.git\n'
        '      path: packages/$pkg\n'
        '      ref: $ref\n';
  }

  final deps = StringBuffer(dep('napp_core', o.kitRef));
  if (o.pro) {
    deps.write(dep('napp_pro', _refFor(o.kitRef, 'pro')));
  }
  if (o.ads) {
    deps.write(dep('napp_ads', _refFor(o.kitRef, 'ads')));
  }
  final flutterBlock = 'dependencies:\n'
      '  flutter:\n'
      '    sdk: flutter\n';
  pubspec = pubspec.replaceFirst(flutterBlock, flutterBlock + deps.toString());
  File(path).writeAsStringSync(pubspec);
  stdout.writeln('güncellendi: $path');
}

String _refFor(String coreRef, String package) =>
    coreRef.replaceFirst('core-', '$package-');

void _writeExampleFiles(_Options o) {
  _writeFile('lib/main.dart', _mainTemplate(o), force: o.force);
  _writeFile(
    '.env.example',
    '# Kullanılan gizli değerler dart-define ile derlemede verilir (1.2).\n',
    force: o.force,
  );
  _writeFile(
    'android/key.properties.example',
    'storeFile=XXXX.jks\n'
    'storePassword=XXXX\n'
    'keyAlias=XXXX\n'
    'keyPassword=XXXX\n'
    'admobAppId=ca-app-pub-XXXX~XXXX\n',
    force: o.force,
  );
  _writeFile(
    'README.md',
    '# ${o.name}\n'
    '\n'
    'napp_app_template şablonundan üretildi: ads=${o.ads ? 'EVET' : 'HAYIR'}, '
    'pro=${o.pro ? 'EVET' : 'HAYIR'}, veri=${o.dataLabel}.\n'
    '\n'
    'Kural kaynağı: ORTAK_UYGULAMA_STANDARDI.md. Proje durumu: PROJECT_BRAIN.md.\n'
    'Lisans: GPL-3.0. Uygulama adı ve logosu markadır; lisansa dahil değildir.\n',
    force: o.force,
  );
}

String _mainTemplate(_Options o) {
  final proImport =
      o.pro ? "import 'package:napp_pro/napp_pro.dart';\n" : '';
  final adsImport = o.ads ? "import 'package:napp_ads/napp_ads.dart';\n" : '';
  return '''
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:napp_core/napp_core.dart';
$proImport$adsImport
// Gizli değerler KODA YAZILMAZ; derlemede --dart-define ile verilir (1.2).
const contactEmail = String.fromEnvironment('CONTACT_EMAIL');
const privacyUrl = String.fromEnvironment('PRIVACY_URL',
    defaultValue: 'https://example.com/privacy');
const sourceUrl = String.fromEnvironment('SOURCE_URL',
    defaultValue: 'https://github.com/XPersPective/${o.projectName}');
const otherAppsUrl = String.fromEnvironment('OTHER_APPS_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SettingsStore.load();
  final themeModeController = ThemeModeController(store: store)..load();
  final identity = AppIdentity(
    appName: '${o.name}',
    packageName: '${o.packageName}',
    sourceUrl: sourceUrl,
    privacyPolicyUrl: privacyUrl,
    contactEmail: contactEmail.isEmpty ? 'hello@example.com' : contactEmail,
    otherAppsUrl: otherAppsUrl.isEmpty ? null : otherAppsUrl,
    sloganKey: 'app.slogan',
  );
  WidgetsBinding.instance.addObserver(SettingsLifecycleObserver(store));
  runApp(NappApp(identity: identity, themeModeController: themeModeController));
}

/// Uygulama iskeleti; uygulamanıza özel ekranları buraya kurun.
class NappApp extends StatelessWidget {
  const NappApp({
    super.key,
    required this.identity,
    required this.themeModeController,
  });

  final AppIdentity identity;
  final ThemeModeController themeModeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeModeController,
      builder: (context, _) => MaterialApp(
        title: identity.appName,
        theme: AppTheme.light(brandColor: identity.brandColor),
        darkTheme: AppTheme.dark(brandColor: identity.brandColor),
        themeMode: themeModeController.mode,
        localizationsDelegates: const [
          NappLocalizationsDelegate(NappTranslations({})),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('tr'), Locale('en')],
        home: HomePage(identity: identity),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.identity});

  final AppIdentity identity;

  @override
  Widget build(BuildContext context) {
    final l10n = NappLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(identity.appName)),
      body: Center(child: Text(l10n.aboutTitle)),
    );
  }
}
''';
}

void _projectBrain(_Options o) {
  final adsRow = o.ads ? 'bölüm 5.2 uygulanır' : 'hiçbir reklam paketi eklenmez';
  final proRow = o.pro
      ? 'bölüm 5.1 uygulanır; ürün kimliği: ${o.productId}'
      : 'satın alma paketi eklenmez';
  final dataRow =
      o.dataCloud ? 'bölüm 6.2 uygulanır' : 'bölüm 6.1 uygulanır';
  _writeFile(
    'PROJECT_BRAIN.md',
    '# PROJECT BRAIN — ${o.name}\n'
    '\n'
    '> **Status:** şablon kuruldu (tool/new_app.dart); geliştirme başlıyor\n'
    '> **Phase:** BUILD · **Next:** T2 · **Updated:** '
    '${DateTime.now().toIso8601String().substring(0, 10)} · **Synced@:** none\n'
    '> **Goal:** v1 #PENDING · **Goal status:** DRAFT\n'
    '\n'
    '## 0. PROJE AYARLARI (ORTAK_UYGULAMA_STANDARDI.md bölüm 0)\n'
    '\n'
    '| Ayar | Değer | Anlamı |\n'
    '|---|---|---|\n'
    '| **REKLAM** | `${o.ads ? 'EVET' : 'HAYIR'}` | $adsRow |\n'
    '| **PRO (ömür boyu)** | `${o.pro ? 'EVET' : 'HAYIR'}` | $proRow |\n'
    '| **VERİ** | `${o.dataLabel}` | $dataRow |\n'
    '\n'
    '## 1. GOAL\n'
    '\n'
    '(Doldurun: uygulamanın amacı, kabul kriterleri, kısıtlar.)\n'
    '\n'
    '## 2. TARGET ARCHITECTURE\n'
    '\n'
    '(Projeye özel mimari: napp paketleri + uygulamanızın katmanları.)\n'
    '\n'
    '## 3. CURRENT ARCHITECTURE\n'
    '\n'
    '${o.name} şablonu: napp_core (${o.pro ? '+ napp_pro, ' : ''}'
    '${o.ads ? '+ napp_ads, ' : ''}dart-define ile AppIdentity), tema,\n'
    'çok dil, kalıcı ayarlar.\n'
    '\n'
    '## 4. FILE MAP / 5. TASKS / 6. DECISION LOG / 7. HANDOFF\n'
    '\n'
    '(project-brain protokolü: PROJECT_BRAIN.md şablonuna bakın.)\n',
    force: o.force,
  );
}

void _checkStandardDoc() {
  const source = 'ORTAK_UYGULAMA_STANDARDI.md';
  if (File(source).existsSync()) {
    stdout.writeln('mevcut: $source');
  } else {
    stdout.writeln('EKSİK: $source — şabondan kopyalanmalı');
  }
}
