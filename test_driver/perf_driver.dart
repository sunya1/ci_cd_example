import 'package:integration_test/integration_test_driver.dart';

/// Writes each `watchPerformance` summary to build/perf/ and prints a table.
Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;

      const columns = {
        'average_frame_build_time_millis': 'UI avg',
        '90th_percentile_frame_build_time_millis': 'UI p90',
        'average_frame_rasterizer_time_millis': 'Rst avg',
        '90th_percentile_frame_rasterizer_time_millis': 'Rst p90',
        'worst_frame_rasterizer_time_millis': 'Rst max',
        'missed_frame_build_budget_count': 'UI miss',
        'missed_frame_rasterizer_budget_count': 'Rst miss',
        'frame_count': 'frames',
      };

      final rows = StringBuffer()
        ..writeln('scenario'.padRight(20) + columns.values.map((c) => c.padLeft(9)).join());
      for (final MapEntry(:key, :value) in data.entries) {
        final summary = (value as Map).cast<String, dynamic>();
        await writeResponseData(
          summary,
          testOutputFilename: key,
          destinationDirectory: 'build/perf',
        );
        rows.writeln(
          key.padRight(20) +
              columns.keys.map((k) {
                final v = summary[k];
                final text = v is double ? v.toStringAsFixed(2) : '$v';
                return text.padLeft(9);
              }).join(),
        );
      }
      // ignore: avoid_print
      print('\n$rows');
    },
  );
}
