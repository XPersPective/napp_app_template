import 'dart:io';

import 'new_app.dart' show dartString, renderTemplate;

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main(List<String> args) async {
  require(
    renderTemplate('A@@IF_X@@B@@IF_Y@@C@@END@@D@@END@@E', {
          'X': true,
          'Y': false,
        }, {}) ==
        'ABDE',
    'nested rendering',
  );
  require(
    renderTemplate('A@@IF_X@@B@@IF_Y@@C@@END@@D@@END@@E', {
          'X': false,
          'Y': true,
        }, {}) ==
        'AE',
    'disabled parent',
  );
  require(dartString(r"a'b$1") == r'''"a'b\$1"''', 'safe Dart literal');
  for (final malformed in [
    '@@END@@',
    '@@IF_X@@',
    '@@IF_UNKNOWN@@@@END@@',
    '@@MISSING@@',
  ]) {
    var rejected = false;
    try {
      renderTemplate(malformed, {'X': true}, {});
    } on StateError {
      rejected = true;
    }
    require(rejected, 'malformed template accepted: $malformed');
  }
  stdout.writeln(
    'PASS: nested rendering, malformed tokens, safe Dart strings.',
  );
  if (!args.contains('--kit-path')) return;
  String value(String flag) => args[args.indexOf(flag) + 1];
  final kit = Directory(value('--kit-path')).absolute.path
      .replaceAll('\\', '/');
  final root = args.contains('--output')
      ? Directory(value('--output')).absolute
      : Directory.systemTemp.createTempSync('napp-factory-matrix-');
  root.createSync(recursive: true);
  stdout.writeln('Isolated matrix: ${root.path}');
  final variants = {
    'free': ['--ads', 'no', '--pro', 'no'],
    'ads_only': ['--ads', 'yes', '--pro', 'no'],
    'lifetime': ['--ads', 'no', '--pro', 'lifetime'],
    'lifetime_ads': ['--ads', 'yes', '--pro', 'yes'],
    'monthly': ['--ads', 'yes', '--pro', 'monthly'],
    'both_ads': ['--ads', 'yes', '--pro', 'both'],
    'all_optional_off': ['--ads', 'no', '--pro', 'no', '--other-apps', 'no'],
  };
  for (final entry in variants.entries) {
    final app = Directory('${root.path}/${entry.key}');
    if (app.existsSync() && app.listSync().isNotEmpty) {
      throw StateError(
        'Refusing to overwrite nonempty matrix app: ${app.path}',
      );
    }
    app.createSync(recursive: true);
    Directory('${app.path}/tool/templates').createSync(recursive: true);
    for (final path in [
      'tool/new_app.dart',
      'tool/templates/main.dart.template',
      'tool/templates/app_test.dart.template',
    ]) {
      File(path).copySync('${app.path}/$path');
    }
    File('ORTAK_UYGULAMA_STANDARDI.md')
        .copySync('${app.path}/ORTAK_UYGULAMA_STANDARDI.md');
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'tool/new_app.dart',
      '--name',
      "Factory 'Test' \$5",
      '--package',
      'com.crazypenguin.factory_${entry.key}',
      ...entry.value,
      '--data',
      'local',
      '--kit-path',
      kit,
      '--force',
      '--skip-build',
    ], workingDirectory: app.path);
    final log = File('${root.path}/${entry.key}.log').openWrite();
    final outputs = [process.stdout, process.stderr].map((stream) async {
      await for (final bytes in stream) {
        log.add(bytes);
      }
    }).toList();
    await Future.wait(outputs);
    final code = await process.exitCode;
    await log.close();
    stdout.writeln('${entry.key}: exit $code (${root.path}/${entry.key}.log)');
    require(code == 0, 'generated ${entry.key} failed');
    final before = File('${app.path}/lib/main.dart').readAsBytesSync();
    final rerun = await Process.run(Platform.resolvedExecutable, [
      'run',
      'tool/new_app.dart',
      '--name',
      'Conflict',
      '--package',
      'com.example.conflict',
      '--ads',
      'no',
      '--pro',
      'no',
      '--data',
      'local',
      '--force',
      '--skip-build',
    ], workingDirectory: app.path);
    require(
      rerun.exitCode != 0 &&
          '${rerun.stderr}'.contains('Refusing existing app'),
      'rerun did not reject existing app before mutation',
    );
    require(
      before.toString() ==
          File('${app.path}/lib/main.dart').readAsBytesSync().toString(),
      'rejected rerun modified main.dart',
    );
    final pubspec = File('${app.path}/pubspec.yaml').readAsStringSync();
    final main = File('${app.path}/lib/main.dart').readAsStringSync();
    if (entry.key == 'free' || entry.key == 'all_optional_off') {
      require(
        !pubspec.contains('napp_ads:') && !pubspec.contains('napp_pro:'),
        'free includes optional SDK dependency',
      );
      final lock = File('${app.path}/pubspec.lock').readAsStringSync();
      require(
        !lock.contains('google_mobile_ads:') &&
            !lock.contains('in_app_purchase:'),
        'free includes transitive optional SDK',
      );
    }
    if (entry.key == 'all_optional_off') {
      require(
        !main.contains('OtherAppsPage('),
        'disabled discover still visible',
      );
    }
    if (entry.key == 'ads_only')
      require(!main.contains('proController'), 'ads-only Pro reference');
    if (entry.key == 'monthly') {
      require(
        main.contains('subscriptionProductId:') && !main.contains('productId:'),
        'monthly misclassified as lifetime',
      );
      require(
        File('${root.path}/monthly.log')
            .readAsStringSync()
            .contains('MONTHLY PRODUCTION BLOCKED'),
        'monthly readiness claim',
      );
    }
    if (entry.key == 'lifetime_ads') {
      require(
        main.contains('appOpenEnabled = false') &&
            main.contains('interstitialEnabled = false'),
        'fullscreen defaults',
      );
    }
  }
  stdout.writeln(
    'PASS: ${variants.length} actual generated apps analyzed/tested; APK build deliberately separate.',
  );
}
