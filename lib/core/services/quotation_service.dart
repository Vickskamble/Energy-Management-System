import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../core/config/subscription_config.dart';
import '../utils/pdf_download_stub.dart'
    if (dart.library.js_interop) '../utils/pdf_download_web.dart' as pdfdl;

/// Generates a professional quotation PDF for PowerEMS — "Brilliants
/// Software Solution". Used for bank-transfer (UTR) payments in-app.
class QuotationService {
  QuotationService._();

  static const String companyName =
      'Brilliants Software Solution (Initiated By Vikas Kamble)';
  static const String companyTagline = 'Energy Management System';

  /// Generate a quotation PDF for the selected plan.
  static Future<Uint8List> generatePDF({
    required String quotationNumber,
    required PlanTier planTier,
    required PlanTerm planTerm,
    required int extraDataPoints,
    String? customerEmail,
  }) async {
    final pdf = pw.Document();
    final plan = SubscriptionConfig.plans[planTier]!;
    final now = DateTime.now();
    final validUntil = now.add(const Duration(days: 30));
    final total =
        SubscriptionConfig.totalAmount(planTier, planTerm, extraDataPoints);
    final base = SubscriptionConfig.baseAmount(planTier, planTerm);
    final extraRate = SubscriptionConfig.extraDPRate(planTier, planTerm);
    final termLabel = SubscriptionConfig.termLabel(planTerm);
    final termName = planTerm.name[0].toUpperCase() +
        planTerm.name.substring(1);
    final dpTotal = plan.includedDataPoints + extraDataPoints;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    companyTagline,
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Support: support@brilliants.in',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'QUOTATION',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '#$quotationNumber',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.blue100,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            height: 4,
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(height: 16),

          // Meta + customer
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (customerEmail != null && customerEmail.isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Prepared For',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      customerEmail,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                )
              else
                pw.SizedBox.shrink(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _metaRow('Date',
                      DateFormat('d MMM yyyy').format(now)),
                  _metaRow('Valid Until',
                      DateFormat('d MMM yyyy').format(validUntil)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Plan details
          _sectionTitle('Plan Details'),
          pw.SizedBox(height: 10),
          _detailRow('Plan', plan.name),
          _detailRow('Billing Term', termName),
          _detailRow('Data Points Included', '${plan.includedDataPoints}'),
          if (extraDataPoints > 0) _detailRow('Extra Data Points', '$extraDataPoints'),
          _detailRow('Total Data Points', '$dpTotal'),
          _detailRow('Extra Data Point Rate', 'Rs $extraRate$termLabel'),

          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 18),

          // What's included
          _sectionTitle('What\'s Included In This Plan'),
          pw.SizedBox(height: 10),
          for (final f in _features(planTier)) _featureRow(f),
          _featureRow('30-day free trial with full access'),

          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 18),

          // Pricing
          _sectionTitle('Pricing'),
          pw.SizedBox(height: 10),
          _priceRow('Base Plan ($termName)', 'Rs $base'),
          if (extraDataPoints > 0)
            _priceRow(
              'Extra Data Points (${extraDataPoints}x Rs $extraRate$termLabel)',
              'Rs ${extraDataPoints * extraRate}',
            ),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL AMOUNT (incl. GST)',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
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
          ),

          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColors.blue200),
          pw.SizedBox(height: 18),

          // Payment options
          _sectionTitle('Payment Options'),
          pw.SizedBox(height: 10),
          pw.Text(
            '1. Razorpay (UPI / Cards / NetBanking)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 10),
            child: pw.Text(
              'Open the PowerEMS app → Plan & Billing → Pay via Razorpay. '
              'The plan activates instantly once the payment is confirmed.',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.Text(
            '2. Bank Transfer (NEFT / RTGS)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                _detailRow('Account Name', BankDetails.accountName),
                _detailRow('Account Number', BankDetails.accountNumber),
                _detailRow('IFSC', BankDetails.ifsc),
                _detailRow('Bank', BankDetails.bankName),
              ],
            ),
          ),

          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 18),

          // Activation steps
          _sectionTitle('How To Activate Your Plan'),
          pw.SizedBox(height: 10),
          _instructionStep('1', 'Select plan details above and confirm the amount.',
            bold: true),
          _instructionStep('2', 'Pay via Razorpay (UPI / cards) or transfer '
            'the exact amount Rs $total to the bank account above.'),
          _instructionStep('3', 'If paying by bank transfer, open the PowerEMS app '
            '→ Plan & Billing → "Paid via bank transfer? Enter UTR".'),
          _instructionStep('4', 'Enter your UTR number and amount paid — '
            'your plan activates instantly once verified.'),

          pw.SizedBox(height: 12),
          pw.Text(
            'Note: Use the exact amount shown above for instant activation.',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey600,
            ),
          ),

          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // Footer
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'Prices are exclusive of GST • Quotation valid for 30 days from the '
                  'date above • "Rs" denotes Indian Rupees (INR).',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'For queries, contact: support@brilliants.in',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '$companyName • Website: app.brilliants.in',
                  style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Share the quotation PDF via the platform share sheet.
  static Future<void> share({
    required String quotationNumber,
    required PlanTier planTier,
    required PlanTerm planTerm,
    required int extraDataPoints,
    String? customerEmail,
  }) async {
    final bytes = await generatePDF(
      quotationNumber: quotationNumber,
      planTier: planTier,
      planTerm: planTerm,
      extraDataPoints: extraDataPoints,
      customerEmail: customerEmail,
    );

    final fileName = 'Quotation_$quotationNumber.pdf';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf'),
        ],
        text: '$companyName — Quotation $quotationNumber\n'
            'Plan: ${SubscriptionConfig.planName(planTier)} '
            '(${planTerm.name})\n'
            'Amount: Rs ${SubscriptionConfig.totalAmount(planTier, planTerm, extraDataPoints)}',
      ),
    );
  }

  /// Download the quotation PDF (real file download on web).
  static Future<void> download({
    required String quotationNumber,
    required PlanTier planTier,
    required PlanTerm planTerm,
    required int extraDataPoints,
    String? customerEmail,
  }) async {
    final bytes = await generatePDF(
      quotationNumber: quotationNumber,
      planTier: planTier,
      planTerm: planTerm,
      extraDataPoints: extraDataPoints,
      customerEmail: customerEmail,
    );
    final fileName = 'Quotation_$quotationNumber.pdf';
    await pdfdl.downloadPdf(bytes, fileName);
  }

  /// Generate a quotation number: BRILL-YYYY-NNN
  static String generateQuotationNumber() {
    final year = DateTime.now().year;
    final seq = DateTime.now().millisecondsSinceEpoch % 999;
    return 'BRILL-$year-${seq.toString().padLeft(3, '0')}';
  }

  /// Feature list that distinguishes each plan tier.
  static List<String> _features(PlanTier tier) {
    final plan = SubscriptionConfig.plans[tier]!;
    final oneLiner = switch (tier) {
      PlanTier.starter => 'Best for a single meter / just starting out',
      PlanTier.growth => 'Most popular — growing businesses',
      PlanTier.pro => 'Best for multi-site / high-capacity operations',
    };
    return [
      oneLiner,
      '${plan.includedDataPoints} data points included & monitored',
      'Add extra data points from Rs ${plan.extraMonthlyRate}/month each',
      'MSEDCL-accurate ToD billing, solar export tracking, '
          'reports & PDF quotation, referral (+1 month free), '
          'max ${SubscriptionConfig.maxExtraDataPoints} extra data points',
    ];
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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

  static pw.Widget _featureRow(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 12,
            height: 12,
            decoration: pw.BoxDecoration(
              color: PdfColors.green100,
              shape: pw.BoxShape.circle,
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              '✓',
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
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

  static pw.Widget _instructionStep(String number, String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
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
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}