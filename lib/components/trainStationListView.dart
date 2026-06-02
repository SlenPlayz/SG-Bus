import 'package:flutter/material.dart';
import 'package:sgbus/scripts/data_management/data.dart';
import 'package:from_css_color/from_css_color.dart';

class TrainStationListTile extends StatelessWidget {
  final dynamic station;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool? showCode;

  const TrainStationListTile({
    super.key,
    required this.station,
    this.onTap,
    this.trailing,
    this.showCode,
  });

  @override
  Widget build(BuildContext context) {
    final List codes = station['codes'] as List? ?? [];

    return ListTile(
      title: Text(station['name'] ?? ''),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: (showCode != false) ? StationCodePills(station: station) : null,
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class StationCodePills extends StatelessWidget {
  final dynamic station;

  const StationCodePills({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final List codes = station['codes'] as List? ?? [];
    final mrtDataMap = getMRTData();
    final lines = mrtDataMap['lines'] as List? ?? [];

    Color getLineColor(String stationCode) {
      for (final l in lines) {
        if (l is Map) {
          final lStations = l['stations'] as List? ?? [];
          for (final s in lStations) {
            if (s is Map && s['code'] == stationCode) {
              final colorStr = l['lineColor'] as String?;
              if (colorStr != null) {
                try {
                  return fromCssColor(colorStr);
                } catch (_) {
                  // Fallback
                }
              }
            }
          }
        }
      }
      return Colors.blueGrey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: codes.asMap().entries.map((entry) {
        final index = entry.key;
        final code = entry.value.toString();
        final isFirst = index == 0;
        final isLast = index == codes.length - 1;

        return Container(
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
          decoration: BoxDecoration(
            color: getLineColor(code),
            borderRadius: BorderRadius.only(
              topLeft: isFirst ? const Radius.circular(50) : Radius.zero,
              bottomLeft: isFirst ? const Radius.circular(50) : Radius.zero,
              topRight: isLast ? const Radius.circular(50) : Radius.zero,
              bottomRight: isLast ? const Radius.circular(50) : Radius.zero,
            ),
          ),
          child: Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontVariations: [
                FontVariation('ROND', 100),
                FontVariation.weight(800),
                FontVariation.width(100),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
