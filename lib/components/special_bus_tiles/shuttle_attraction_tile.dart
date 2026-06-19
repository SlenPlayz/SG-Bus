import 'package:flutter/material.dart';

class ShuttleAttractionTile extends StatefulWidget {
  final dynamic data;
  final VoidCallback? onTap;
  const ShuttleAttractionTile(this.data, {Key? key, this.onTap})
      : super(key: key);

  @override
  State<ShuttleAttractionTile> createState() => _ShuttleAttractionTileState();
}

class _ShuttleAttractionTileState extends State<ShuttleAttractionTile> {
  var name;
  var subtitle;

  void initState() {
    super.initState();
    if (widget.data['ServiceNo'].toString().contains(" - ")) {
      name = widget.data['ServiceNo'].toString().split(" - ")[1];
      subtitle = widget.data['ServiceNo'].toString().split(" - ")[0];
    } else {
      name = widget.data['ServiceNo'] ?? '';
    }

    if (subtitle.toString().startsWith("RWS")) {
      name = widget.data['ServiceNo'].toString().split(" - ")[0];
      subtitle = widget.data['ServiceNo'].toString().split(" - ")[1];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.attractions_rounded),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: widget.onTap,
      title: Text(
        name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontVariations: [
            FontVariation('ROND', 100),
            FontVariation.width(90),
            FontVariation.weight(800),
          ],
        ),
      ),
    );
  }
}
