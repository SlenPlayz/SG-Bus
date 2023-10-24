import 'package:flutter/material.dart';
import 'package:sgbus/pages/bus_route.dart';
import 'package:sgbus/components/bus_timing_est.dart';

class BusTiming extends StatefulWidget {
  final data;
  const BusTiming(this.data);

  @override
  _BusTimingState createState() => _BusTimingState();
}

class _BusTimingState extends State<BusTiming> {
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          BusRoute(widget.data['ServiceNo'])));
            },
            child: Container(
              width: width,
              decoration: BoxDecoration(
                border: Border.all(color: (Colors.transparent)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.5),
                child: Row(
                  children: [
                    SizedBox(
                      width: width * 0.2,
                      child: Column(
                        children: [
                          Text(widget.data['ServiceNo'],
                              style: Theme.of(context).textTheme.titleLarge),
                          Text(
                            widget.data["to"] ?? "",
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          )
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(children: [
                      BusTimingEst(data: widget.data['NextBus'] ?? null),
                      BusTimingEst(data: widget.data['NextBus2'] ?? null),
                      BusTimingEst(data: widget.data['NextBus3'] ?? null)
                    ]),
                  ],
                ),
              ),
            ),
          ),
          Divider(color: Theme.of(context).dividerColor)
        ],
      ),
    );
  }
}
