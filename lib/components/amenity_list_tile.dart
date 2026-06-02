import 'package:flutter/material.dart';
import 'package:sgbus/pages/mrt_pages/amenity_stations_page.dart';

class AmenityListTile extends StatelessWidget {
  final Map<String, dynamic> amenity;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final bool showSubtitle;

  const AmenityListTile({
    super.key,
    required this.amenity,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
    required this.showSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    const bigR = Radius.circular(28.0);
    const smallR = Radius.circular(5.0);

    final name = amenity['name'] as String? ?? 'Unknown';
    final type = amenity['type'] as String? ?? '';
    final desc = amenity['description'] as String? ?? '';
    final unit = amenity['unit'] as String?;

    IconData iconData;
    switch (type.toLowerCase()) {
      case 'atm':
        iconData = Icons.local_atm_rounded;
        break;
      case 'shop':
        iconData = Icons.storefront;
        break;
      case 'ticket_office':
        iconData = Icons.confirmation_num_outlined;
        break;
      case 'bicycle racks':
        iconData = Icons.pedal_bike;
        break;
      default:
        iconData = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: isFirst ? bigR : smallR,
          topRight: isFirst ? bigR : smallR,
          bottomLeft: isLast ? bigR : smallR,
          bottomRight: isLast ? bigR : smallR,
        ),
        color:
            Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
      ),
      child: ListTile(
        leading: Icon(iconData, color: Theme.of(context).colorScheme.primary),
        title: Text(name + (type.toUpperCase() == "ATM" ? " ATM" : "")),
        subtitle: showSubtitle
            ? unit != null
                ? Text(unit)
                : type.toUpperCase() == "ATM"
                    ? Text(type)
                    : desc != ""
                        ? Text(desc)
                        : null
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AmenityStationsPage(
                amenityName: name,
              ),
            ),
          );
        },
      ),
    );
  }
}
