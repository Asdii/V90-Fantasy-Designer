import '../models/x_axis_calibration.dart';
import 'json_storage.dart';
import 'key_value_store.dart';

/// One physical calibration per machine; simulated data has its own identity.
class XAxisRepository {
  XAxisRepository(KeyValueStore store)
    : _items = JsonCollection<AxisCalibration>(
        store: store,
        key: 'microfantasy.x_axis.v1',
        fromJson: AxisCalibration.fromJson,
        toJson: (c) => c.toJson(),
        idOf: (c) => c.deviceId,
      );
  final JsonCollection<AxisCalibration> _items;
  Future<List<AxisCalibration>> load() => _items.load();
  Future<void> save(AxisCalibration calibration) => _items.save(calibration);
  Future<void> delete(String deviceId) => _items.delete(deviceId);
}
