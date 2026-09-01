import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('pdf Chart + FixedAxis + LineDataSet render without runtime error',
      () async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.SizedBox(
            height: 160,
            width: double.maxFinite,
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis<int>(
                  const [1, 10, 20, 31],
                  divisions: true,
                  ticks: true,
                  format: (v) => v.toString(),
                ),
                yAxis: pw.FixedAxis<double>(
                  const [0.0, 0.50, 0.80, 0.95, 1.0],
                  divisions: true,
                  ticks: true,
                ),
              ),
              datasets: [
                pw.LineDataSet<pw.PointChartValue>(
                  data: [
                    for (var d = 1; d <= 31; d++)
                      pw.PointChartValue(d.toDouble(), 0.80 + (d % 7) * 0.01),
                  ],
                  legend: 'PF',
                  color: PdfColors.blue,
                  pointSize: 2,
                  lineWidth: 1.5,
                ),
              ],
            ),
          ),
          pw.Text('PF Trend smoke test'),
        ],
      ),
    );

    final Uint8List bytes = await doc.save();
    expect(bytes.length, greaterThan(1000));
  });
}