import 'package:flutter/material.dart';

class BusTimingEst extends StatelessWidget {
  const BusTimingEst({Key? key, this.data, this.isCM = false})
      : super(key: key);
  final data;
  final bool isCM;

  Widget _buildInfoPill(BuildContext context, String label) {
    Widget pill = Padding(
      padding: const EdgeInsets.only(top: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 8.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontVariations: const [
                    FontVariation('ROND', 100),
                    FontVariation.weight(600),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (label == 'Estimated') {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Estimated timings are based on Citymapper data"),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        },
        child: pill,
      );
    }

    return pill;
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    String estimatedArrTime = '';
    String doubleStat = '';
    double textOpacity = 1.0;
    bool isLive = false;
    bool isScheduled = false;

    final bool cmActive =
        isCM || (data != null && (data['CM'] == true || data['CM'] == 'true'));

    bool hasArrivalData = false;
    bool hasType = false;
    bool hasLoad = false;
    bool hasFeature = false;

    if (data != null &&
        data["EstimatedArrival"] != null &&
        data["EstimatedArrival"] != '') {
      hasArrivalData = true;
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
        int minutes = diff.round();
        if (minutes > 60) {
          int hours = (minutes / 60.0).round();
          estimatedArrTime = '${hours}h';
        } else {
          estimatedArrTime = minutes.toString();
        }
      }
      if (data['Type'] == 'SD') {
        doubleStat = 'Single';
      } else if (data['Type'] == 'DD') {
        doubleStat = 'Double';
      } else if (data['Type'] == 'BD') {
        doubleStat = 'Bendy';
      }

      hasType = doubleStat.isNotEmpty;
      hasLoad =
          data['Load'] != null && data['Load'].toString().trim().isNotEmpty;
      hasFeature = data['Feature'] != null &&
          data['Feature'].toString().trim().isNotEmpty;

      final monitoredVal = data['Monitored'];

      if (cmActive) {
        isScheduled = true;
        textOpacity = 0.7;
      } else if (monitoredVal == 1 || monitoredVal == '1') {
        isLive = true;
      } else if (monitoredVal == 0 || monitoredVal == '0') {
        isScheduled = true;
        // Scheduled timing (based on operator schedule) - 70% opacity
        textOpacity = 0.7;
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: textOpacity,
                  child: Text(
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
                ),
                if (isLive)
                  Positioned(
                    top: -3,
                    right: -13,
                    child: Icon(
                      Icons.rss_feed_rounded,
                      size: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                else if (isScheduled)
                  Positioned(
                    top: -3,
                    right: -13,
                    child: Opacity(
                      opacity: textOpacity,
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
            if (hasArrivalData)
              if (cmActive)
                _buildInfoPill(context, 'Estimated')
              else if (!hasType && !hasLoad && !hasFeature)
                _buildInfoPill(context, 'Unavailable')
              else
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
