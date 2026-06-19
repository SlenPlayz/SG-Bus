import 'package:flutter/material.dart';
import 'package:sgbus/pages/bus_route.dart';

class PublicBusTile extends StatelessWidget {
  final String serviceNo;
  final String route;
  final bool isFirst;
  final VoidCallback? onTap;
  const PublicBusTile({
    Key? key,
    required this.serviceNo,
    required this.route,
    this.isFirst = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.directions_bus_rounded),
      title: Text(
        serviceNo,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontVariations: [
            FontVariation('ROND', 100),
            FontVariation.width(110),
            FontVariation.weight(800),
          ],
        ),
      ),
      subtitle: Text(route),
      onTap: onTap,
    );
  }
}
