import 'package:flutter/material.dart';

class BusTimingEst extends StatelessWidget {
  const BusTimingEst({Key? key, this.data}) : super(key: key);
  final data;

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    String estimatedArrTime = '';
    String doubleStat = '';

    if (data != null && data["EstimatedArrival"] != '') {
      int estArrTimeUnix = (DateTime.parse(data["EstimatedArrival"])
          .toUtc()
          .millisecondsSinceEpoch);
      int currUnixTime = DateTime.now().millisecondsSinceEpoch;
      double diff = (((estArrTimeUnix - currUnixTime) / 1000) / 60);

      if (diff < -0.5) {
        estimatedArrTime = 'Left';
      } else if (diff < 1) {
        estimatedArrTime = 'Arr';
      } else {
        estimatedArrTime = diff.round().toString();
      }
      if (data['Type'] == 'SD') {
        doubleStat = 'Single';
      } else if (data['Type'] == 'DD') {
        doubleStat = 'Double';
      } else if (data['Type'] == 'BD') {
        doubleStat = 'Bendy';
      }
    } else {
      estimatedArrTime = '-';
    }

    return SizedBox(
        width: width * 0.2,
        child: Column(
          children: [
            Text(estimatedArrTime,
                style: Theme.of(context).textTheme.headline6,
                textAlign: TextAlign.center),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: (data != null)
                          ? (data['Load'] != '')
                              ? (data['Load'] == 'SEA')
                                  ? Colors.green[200]
                                  : (data['Load'] == 'SDA')
                                      ? Colors.amber[200]
                                      : Colors.red[200]
                              : Colors.transparent
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Text(doubleStat, textAlign: TextAlign.center)
              ],
            ),
          ],
        ));
  }
}
