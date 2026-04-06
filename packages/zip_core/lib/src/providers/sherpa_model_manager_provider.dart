import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/services/catalog/sherpa_model_manager.dart';

part 'sherpa_model_manager_provider.g.dart';

/// Provides the singleton [SherpaModelManager].
///
/// Configures [Dio] with PERF-U2.3 timeouts and resolves the platform
/// storage directory.
@Riverpod(keepAlive: true)
Future<SherpaModelManager> sherpaModelManager(Ref ref) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  final appDir = await getApplicationSupportDirectory();
  final storageDir = Directory('${appDir.path}/sherpa_models');
  if (!storageDir.existsSync()) {
    await storageDir.create(recursive: true);
  }

  return SherpaModelManager(dio: dio, storageDir: storageDir);
}
