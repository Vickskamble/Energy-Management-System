import 'package:flutter/material.dart';
import '../../theme/power_theme.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current bill card (hero)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PowerTheme.lime,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Bill Period',
                    style: PowerTextStyles.body(
                        size: 12, color: PowerTheme.onLime.withAlpha(180))),
                const SizedBox(height: 4),
                Text('01 Jun — 30 Jun 2026',
                    style: PowerTextStyles.heading(
                        size: 16, color: PowerTheme.onLime)),
                const SizedBox(height: 20),
                Text('Estimated Bill',
                    style: PowerTextStyles.body(
                        size: 13, color: PowerTheme.onLime.withAlpha(180))),
                const SizedBox(height: 4),
                Text('₹1,24,850',
                    style: PowerTextStyles.mono(
                        size: 36, color: PowerTheme.onLime)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _billStat('Energy Charge', '₹89,500', PowerTheme.onLime),
                    _billStat('Demand Charge', '₹28,000', PowerTheme.onLime),
                    _billStat('PF Surcharge', '₹7,350', PowerTheme.danger),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Rate card
          _section('Tariff Rates'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PowerTheme.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PowerTheme.border),
            ),
            child: Column(
              children: [
                _rateRow('Energy Charge', '₹6.50/kWh'),
                _rateRow('Demand Charge', '₹200/kVA'),
                _rateRow('PF Penalty', '<0.9 lagging'),
                _rateRow('Fixed Charge', '₹5,000/month'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // History
          _section('Billing History'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PowerTheme.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PowerTheme.border),
            ),
            child: Column(
              children: [
                _historyRow('May 2026', '₹1,18,200', '14,200 kWh', false),
                _historyRow('Apr 2026', '₹1,12,400', '13,800 kWh', false),
                _historyRow('Mar 2026', '₹1,05,800', '12,900 kWh', false),
                _historyRow('Feb 2026', '₹98,500', '12,100 kWh', false),
                _historyRow('Jan 2026', '₹1,02,300', '12,500 kWh', false),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Savings insight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PowerTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PowerTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb, size: 20, color: PowerTheme.lime),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Improving PF to 0.95 could save ~₹4,500/month on surcharges',
                    style: PowerTextStyles.body(size: 13, color: PowerTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: PowerTextStyles.heading(size: 16)),
    );
  }

  Widget _billStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: PowerTextStyles.mono(size: 13, color: color)),
          Text(label,
              style: PowerTextStyles.body(size: 10, color: PowerTheme.onLime.withAlpha(150))),
        ],
      ),
    );
  }

  Widget _rateRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PowerTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: PowerTextStyles.body(size: 13)),
          Text(value,
              style: PowerTextStyles.mono(size: 13, color: PowerTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _historyRow(String month, String amount, String units, bool isCurrent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: PowerTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(month,
                style: PowerTextStyles.body(size: 13, weight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Text(amount,
                style: PowerTextStyles.mono(size: 13, color: PowerTheme.textPrimary)),
          ),
          Expanded(
            child: Text(units,
                style: PowerTextStyles.body(size: 12, color: PowerTheme.textMuted),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
