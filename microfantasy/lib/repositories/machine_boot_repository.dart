import '../models/validation.dart';
import 'json_storage.dart';
import 'key_value_store.dart';

/// Receipt and unread state are separate. A receipt is sent to the board only
/// after this record is durable, so closing the app cannot lose the notice.
class MachineBootRecord {
  const MachineBootRecord({
    required this.deviceId,
    required this.bootId,
    this.unread = true,
  });
  final String deviceId;
  final String bootId;
  final bool unread;

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'bootId': bootId,
    'unread': unread,
  };
  factory MachineBootRecord.fromJson(Map<String, Object?> json) {
    if (json['unread'] is! bool) {
      throw const FormatException('Invalid boot notice');
    }
    return MachineBootRecord(
      deviceId: nonEmptyString(json['deviceId'], 'deviceId'),
      bootId: nonEmptyString(json['bootId'], 'bootId'),
      unread: json['unread'] as bool,
    );
  }
}

class MachineBootRepository {
  MachineBootRepository(KeyValueStore store)
    : _items = JsonCollection<MachineBootRecord>(
        store: store,
        key: 'microfantasy.machine_boots.v1',
        fromJson: MachineBootRecord.fromJson,
        toJson: (record) => record.toJson(),
        idOf: (record) => record.deviceId,
      );
  final JsonCollection<MachineBootRecord> _items;
  Future<List<MachineBootRecord>> load() => _items.load();
  Future<void> save(MachineBootRecord record) => _items.save(record);
}
