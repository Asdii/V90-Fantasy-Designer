/// Runtime validation shared by the domain and JSON persistence boundaries.
///
/// Invalid user/imported data always produces a [FormatException], including
/// when assertions are disabled in a release build.
Map<String, Object?> jsonObject(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$field must be a JSON object.');
  }
  return value;
}

List<Object?> jsonList(Object? value, String field) {
  if (value is! List<Object?>) {
    throw FormatException('$field must be a JSON array.');
  }
  return value;
}

String nonEmptyString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value;
}

double finiteNumber(Object? value, String field) {
  if (value is! num || !value.isFinite) {
    throw FormatException('$field must be a finite number.');
  }
  final double result = value.toDouble();
  if (!result.isFinite) {
    throw FormatException('$field is outside the supported numeric range.');
  }
  return result;
}

double nonNegativeNumber(Object? value, String field) {
  final double result = finiteNumber(value, field);
  if (result < 0) {
    throw FormatException('$field must be non-negative.');
  }
  return result;
}

double boundedNumber(Object? value, String field, double min, double max) {
  final double result = finiteNumber(value, field);
  if (result < min || result > max) {
    throw FormatException('$field must be between $min and $max.');
  }
  return result;
}

int integer(Object? value, String field, {int? min, int? max}) {
  if (value is! num || !value.isFinite || value != value.roundToDouble()) {
    throw FormatException('$field must be an integer.');
  }
  final int result = value.toInt();
  if (result != value ||
      (min != null && result < min) ||
      (max != null && result > max)) {
    throw FormatException('$field is outside the supported integer range.');
  }
  return result;
}

bool boolean(Object? value, String field) {
  if (value is! bool) {
    throw FormatException('$field must be a boolean.');
  }
  return value;
}

T enumValue<T extends Enum>(Object? value, List<T> values, String field) {
  for (final T candidate in values) {
    if (candidate.name == value) {
      return candidate;
    }
  }
  throw FormatException(
    '$field must be one of ${values.map((T item) => item.name).join(', ')}.',
  );
}

/// Missing fields may use a default. Explicitly invalid/null values may not.
Object? valueOrDefault(Map<String, Object?> json, String key, Object fallback) {
  return json.containsKey(key) ? json[key] : fallback;
}

/// Canonical degrees in [0, 360), with 360 and negative zero mapped to zero.
double normalizeDegrees(double angle) {
  finiteNumber(angle, 'angleR');
  final double normalized = angle % 360;
  return normalized == 0 || normalized == 360 ? 0 : normalized;
}
