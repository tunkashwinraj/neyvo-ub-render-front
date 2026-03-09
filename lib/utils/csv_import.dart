// Simple CSV parse for student import. Supports quoted fields.

/// Parse one CSV line into list of fields. Handles "quoted" fields.
List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  var i = 0;
  while (i < line.length) {
    if (line[i] == '"') {
      i++;
      final sb = StringBuffer();
      while (i < line.length) {
        if (line[i] == '"') {
          i++;
          if (i < line.length && line[i] == '"') {
            sb.write('"');
            i++;
          } else {
            break;
          }
        } else {
          sb.write(line[i]);
          i++;
        }
      }
      fields.add(sb.toString());
      if (i < line.length && line[i] == ',') i++;
    } else {
      final comma = line.indexOf(',', i);
      if (comma == -1) {
        fields.add(line.substring(i).trim());
        break;
      }
      fields.add(line.substring(i, comma).trim());
      i = comma + 1;
    }
  }
  return fields;
}

/// Parse CSV string into list of rows (each row = list of fields).
List<List<String>> parseCsv(String text) {
  final lines = text.split(RegExp(r'\r\n|\r|\n'));
  final rows = <List<String>>[];
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    if (line.trimLeft().startsWith('#')) continue;
    final row = _parseCsvLine(line);
    // Skip rows that are syntactically present but effectively empty, e.g. ",,,,,"
    if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;
    rows.add(row);
  }
  return rows;
}

/// Parse CSV and return list of maps (first row = headers). Keys lowercased.
List<Map<String, String>> parseCsvToMaps(String text) {
  final rows = parseCsv(text);
  if (rows.isEmpty) return [];
  final headers = rows.first
      .map((e) => e.replaceAll('\uFEFF', '').toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_'))
      .toList();
  final result = <Map<String, String>>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final map = <String, String>{};
    for (var j = 0; j < headers.length && j < row.length; j++) {
      map[headers[j]] = row[j].trim();
    }
    if (map.values.every((v) => v.trim().isEmpty)) continue;
    result.add(map);
  }
  return result;
}
