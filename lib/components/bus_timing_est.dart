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
        height: (data != null &&
                data["VisitNumber"] != null &&
                data["VisitNumber"] == "2")
            ? 65
            : 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              estimatedArrTime,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontVariations: [
                  FontVariation('ROND', 100),
                  FontVariation.width(105),
                  FontVariation.weight(700)
                ],
              ),
              textAlign: TextAlign.center,
            ),
            if (doubleStat != "")
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  Text(
                    doubleStat,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontVariations: [
                      FontVariation('ROND', 100),
                      FontVariation.width(90),
                      FontVariation.weight(500)
                    ], color: Theme.of(context).colorScheme.onSurface),
                  ),
                  data != null &&
                          data["Feature"] != null &&
                          data["Feature"] != "" &&
                          data["Feature"] != "WAB"
                      ? Icon(
                          Icons.not_accessible,
                          size: 14,
                        )
                      : Container()
                ],
              ),
            if (data != null &&
                data["VisitNumber"] != null &&
                data["VisitNumber"] == "2")
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  Text(
                    "2nd Visit",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10),
                  ),
                ],
              )
          ],
        ));
  }
}
