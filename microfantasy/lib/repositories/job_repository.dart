import 'dart:convert';

import '../models/cutting_job.dart';
import '../models/validation.dart';
import 'json_storage.dart';
import 'key_value_store.dart';

class JobRepository {
  JobRepository(KeyValueStore store)
    : _collection = JsonCollection<CuttingJob>(
        store: store,
        key: storageKey,
        fromJson: CuttingJob.fromJson,
        toJson: (CuttingJob job) => job.toJson(),
        idOf: (CuttingJob job) => job.jobId,
      );

  static const String storageKey = 'microfantasy.jobs.v1';
  final JsonCollection<CuttingJob> _collection;

  Future<List<CuttingJob>> load() => _collection.load();
  Future<void> save(CuttingJob job) => _collection.save(job);
  Future<void> delete(String id) => _collection.delete(id);

  /// Parsing is side-effect free; accepting and saving an imported job is a
  /// separate controller action.
  CuttingJob importJson(String source) =>
      CuttingJob.fromJson(jsonObject(jsonDecode(source), 'job'));

  String exportJson(CuttingJob job) =>
      const JsonEncoder.withIndent('  ').convert(job.toJson());
}
