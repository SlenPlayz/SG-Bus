import 'package:flutter/material.dart';

class PremiumBusTile extends StatefulWidget {
  final dynamic data;
  final VoidCallback? onTap;
  const PremiumBusTile(this.data, {Key? key, this.onTap}) : super(key: key);

  @override
  State<PremiumBusTile> createState() => _PremiumBusTileState();
}

class _PremiumBusTileState extends State<PremiumBusTile> {
  var name;
  var subtitle;

  void initState() {
    super.initState();
    if (widget.data['ServiceNo'].toString().contains(" - ")) {
      name = widget.data['ServiceNo'].toString().split(" - ")[0];
      subtitle = widget.data['ServiceNo'].toString().split(" - ")[1];
    } else {
      name = widget.data['ServiceNo'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.corporate_fare_rounded),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: widget.onTap,
      title: Text(
        name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontVariations: [
            FontVariation('ROND', 100),
            FontVariation.width(110),
            FontVariation.weight(800),
          ],
        ),
      ),
    );
  }
}
