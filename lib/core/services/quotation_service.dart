import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../core/config/subscription_config.dart';

/// Generates a professional quotation PDF for bank-transfer payments.
class QuotationService {
  QuotationService._();

  /// Generate a quotation PDF for the selected plan.
  static Future<Uint8List> generatePDF({
    required String quotationNumber,
    required PlanTier planTier,
    required PlanTerm planTerm,
    required int extraDataPoints,
  }) async {
    final pdf = pw.Document();
    final plan = SubscriptionConfig.plans[planTier]!;
    final now = DateTime.now();
    final validUntil = now.add(const Duration(days: 30));
    final total = SubscriptionConfig.totalAmount(planTier, planTerm, extraDataPoints);
    final base = SubscriptionConfig.baseAmount(planTier, planTerm);
    final extraRate = SubscriptionConfig.extraDPRate(planTier, planTerm);
    final termLabel = SubscriptionConfig.termLabel(planTerm);
    final dpTotal = plan.includedDataPoints + extraDataPoints;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'BRILLIANTS',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Energy Management System',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'QUOTATION',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Quotation #: $quotationNumber',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('d MMM yyyy').format(now)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Valid Until: ${DateFormat('d MMM yyyy').format(validUntil)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.blue200),
          pw.SizedBox(height: 20),

          // Plan Details
          pw.Text(
            'Plan Details',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          _detailRow('Plan', plan.name),
          _detailRow('Billing Term', planTerm.name[0].toUpperCase() + planTerm.name.substring(1)),
          _detailRow('Data Points Included', '${plan.includedDataPoints}'),
          if (extraDataPoints > 0)
            _detailRow('Extra Data Points', '$extraDataPoints'),
          _detailRow('Total Data Points', '$dpTotal'),

          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 20),

          // Pricing
          pw.Text(
            'Pricing',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          _priceRow('Base Plan${termLabel == '/yr' ? ' (Yearly)' : termLabel == '/qtr' ? ' (Quarterly)' : ' (Monthly)'}', 'Rs $base'),
          if (extraDataPoints > 0)
            _priceRow(
              'Extra Data Points ($extraDataPoints x Rs $extraRate$termLabel)',
              'Rs ${extraDataPoints * extraRate}',
            ),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TOTAL AMOUNT',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Rs $total',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.blue200),
          pw.SizedBox(height: 20),

          // Bank Details
          pw.Text(
            'Bank Transfer Details',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          _detailRow('Account Name', BankDetails.accountName),
          _detailRow('Account Number', BankDetails.accountNumber),
          _detailRow('IFSC', BankDetails.ifsc),
          _detailRow('Bank', BankDetails.bankName),

          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 20),

          // Instructions
          pw.Text(
            'How to Activate Your Plan',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          _instructionStep('1', 'Transfer Rs $total to the bank account above via NEFT/RTGS.'),
          _instructionStep('2', 'Open the PowerEMS app and go to Plan & Billing.'),
          _instructionStep('3', 'Select "Bank Transfer" and enter your UTR number + amount paid.'),
          _instructionStep('4', 'Your plan activates instantly once verified.'),
          pw.SizedBox(height: 8),
          pw.Text(
            'Note: Please use the exact amount shown above for instant activation.',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey600,
            ),
          ),

          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'For queries, contact: support@brilliants.in',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Share the quotation PDF via platform share sheet.
  static Future<void> share({
    required String quotationNumber,
    required PlanTier planTier,
    required PlanTerm planTerm,
    required int extraDataPoints,
  }) async {
    final bytes = await generatePDF(
      quotationNumber: quotationNumber,
      planTier: planTier,
      planTerm: planTerm,
      extraDataPoints: extraDataPoints,
    );

    final fileName = 'Quotation_$quotationNumber.pdf';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
        text: 'PowerEMS Quotation — $quotationNumber\n'
            'Plan: ${SubscriptionConfig.planName(planTier)} '
            '(${planTerm.name})\n'
            'Amount: Rs ${SubscriptionConfig.totalAmount(planTier, planTerm, extraDataPoints)}',
      ),
    );
  }

  /// Generate a quotation number: BRILL-YYYY-NNN
  static String generateQuotationNumber() {
    final year = DateTime.now().year;
    final seq = DateTime.now().millisecondsSinceEpoch % 999;
    return 'BRILL-$year-${seq.toString().padLeft(3, '0')}';
  }

  static pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _priceRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  static pw.Widget _instructionStep(String number, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 20,
            height: 20,
            decoration: pw.BoxDecoration(
              color: PdfColors.blue100,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              number,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
