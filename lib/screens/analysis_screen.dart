import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ems_provider.dart';
import '../models/analysis_result.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights & Analysis'),
        actions: [
          Consumer<EmsProvider>(
            builder: (_, provider, _) {
              final siteId = provider.selectedSite?.id;
              if (siteId == null) return const SizedBox.shrink();
              return IconButton(
                icon: provider.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: provider.loading
                    ? null
                    : () => provider.runFullAnalysis(siteId),
              );
            },
          ),
        ],
      ),
      body: Consumer<EmsProvider>(
        builder: (_, provider, _) {
          if (provider.analysisResults.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No analysis results yet',
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Add readings and run analysis to get insights',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  if (provider.selectedSite != null) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => provider.runFullAnalysis(
                          provider.selectedSite!.id),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Run Full Analysis'),
                    ),
                  ],
                ],
              ),
            );
          }

          final critical = provider.analysisResults
              .where((a) => a.severity == Severity.critical)
              .toList();
          final high = provider.analysisResults
              .where((a) => a.severity == Severity.high)
              .toList();
          final others = provider.analysisResults
              .where((a) => a.severity != Severity.critical &&
                  a.severity != Severity.high)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (critical.isNotEmpty) ...[
                _sectionHeader(context, 'Critical', Colors.red),
                ...critical.map((a) => _analysisCard(context, a)),
                const SizedBox(height: 12),
              ],
              if (high.isNotEmpty) ...[
                _sectionHeader(context, 'High Priority', Colors.orange),
                ...high.map((a) => _analysisCard(context, a)),
                const SizedBox(height: 12),
              ],
              if (others.isNotEmpty) ...[
                _sectionHeader(context, 'Other Findings', Colors.grey),
                ...others.map((a) => _analysisCard(context, a)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _analysisCard(BuildContext context, AnalysisResult result) {
    Color severityColor;
    switch (result.severity) {
      case Severity.critical:
        severityColor = Colors.red;
      case Severity.high:
        severityColor = Colors.orange;
      case Severity.medium:
        severityColor = Colors.amber;
      case Severity.low:
        severityColor = Colors.grey;
    }

    IconData typeIcon;
    switch (result.type) {
      case AnalysisType.highLoad:
        typeIcon = Icons.trending_up;
      case AnalysisType.contractDemandExceeded:
        typeIcon = Icons.gavel;
      case AnalysisType.powerFactorIssue:
        typeIcon = Icons.power;
      case AnalysisType.voltageIssue:
        typeIcon = Icons.bolt;
      case AnalysisType.currentUnbalance:
        typeIcon = Icons.balance;
      case AnalysisType.harmonicIssue:
        typeIcon = Icons.waves;
      case AnalysisType.anomaly:
        typeIcon = Icons.error_outline;
      case AnalysisType.energySaving:
        typeIcon = Icons.savings;
      case AnalysisType.general:
        typeIcon = Icons.info_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: severityColor.withAlpha(30),
          child: Icon(typeIcon, color: severityColor, size: 20),
        ),
        title: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: severityColor, shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(result.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        subtitle: Text(
          '${_formatType(result.type)}  •  ${result.severity.name.toUpperCase()}',
          style: TextStyle(fontSize: 11, color: severityColor),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.description,
                    style: TextStyle(color: Colors.grey[700])),
                if (result.recommendation != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb, size: 18, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            result.recommendation!,
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (result.metrics != null && result.metrics!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: result.metrics!.entries.map((e) {
                      return Chip(
                        label: Text('${e.key}: ${e.value}',
                            style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatType(AnalysisType type) {
    return type.name[0].toUpperCase() + type.name.substring(1);
  }
}
