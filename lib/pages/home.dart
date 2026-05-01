import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sgbus/components/searchBar.dart';
import 'package:sgbus/components/favouritesWidget.dart';
import 'package:sgbus/components/nearbyWidget.dart';
import 'package:sgbus/pages/alert_webview_page.dart';
import 'package:sgbus/pages/cepas_reader.dart';
import 'package:sgbus/scripts/data.dart';

import 'dart:ui' as ui;

import 'package:url_launcher/url_launcher.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int count = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              // alignment: Alignment.bottomRight,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(28.0)),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder(
                              valueListenable: globalAlerts,
                              builder: (context, value, child) {
                                var alerts = globalAlerts.value;

                                return AnimatedSize(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topRight,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (alerts.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              8, 8, 5, 5),
                                          child: Text(
                                            "Alerts:",
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error,
                                                ),
                                          ),
                                        ),
                                      for (var alert in alerts.asMap().entries)
                                        if (alert.value["type"] == "text" ||
                                            alert.value["type"] == "webview")
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 2),
                                            child: Container(
                                              margin:
                                                  EdgeInsets.only(bottom: 1),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.only(
                                                  topLeft: alert.key == 0
                                                      ? Radius.circular(28.0)
                                                      : Radius.circular(5),
                                                  topRight: alert.key == 0
                                                      ? Radius.circular(28.0)
                                                      : Radius.circular(5),
                                                  bottomLeft: alert.key ==
                                                          alerts.length - 1
                                                      ? Radius.circular(28.0)
                                                      : Radius.circular(5),
                                                  bottomRight: alert.key ==
                                                          alerts.length - 1
                                                      ? Radius.circular(28.0)
                                                      : Radius.circular(5),
                                                ),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceVariant
                                                    .withOpacity(0.3),
                                              ),
                                              child: ListTile(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onTap: () {
                                                  if (alert.value["type"] ==
                                                      "webview") {
                                                    Navigator.of(context).push(MaterialPageRoute(
                                                        builder: (context) =>
                                                            AlertWebviewPage(
                                                                header: alert
                                                                        .value[
                                                                    "header"],
                                                                message: alert
                                                                        .value[
                                                                    "message"],
                                                                link:
                                                                    alert.value[
                                                                        "link"],
                                                                linkDesc: alert
                                                                        .value[
                                                                    "linkDesc"])));
                                                  }
                                                  if (alert.value["type"] ==
                                                      "text") {
                                                    showModalBottomSheet(
                                                      context: context,
                                                      builder: (BuildContext
                                                          context) {
                                                        return BottomSheet(
                                                          onClosing: () {},
                                                          showDragHandle: true,
                                                          builder: (BuildContext
                                                              context) {
                                                            return SingleChildScrollView(
                                                                child: Column(
                                                              children: [
                                                                Padding(
                                                                  padding: EdgeInsets
                                                                      .fromLTRB(
                                                                          15,
                                                                          0,
                                                                          15,
                                                                          0),
                                                                  child:
                                                                      Container(
                                                                    width: double
                                                                        .infinity,
                                                                    child: Text(
                                                                      alert.value[
                                                                          "header"],
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .titleMedium
                                                                          ?.copyWith(
                                                                        fontVariations: [
                                                                          FontVariation(
                                                                              'ROND',
                                                                              100),
                                                                          FontVariation.width(
                                                                              100),
                                                                          FontVariation.weight(
                                                                              1000)
                                                                        ],
                                                                      ),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .left,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .fromLTRB(
                                                                          15.0,
                                                                          15,
                                                                          15,
                                                                          100),
                                                                  child:
                                                                      MarkdownBody(
                                                                    data: alert
                                                                            .value[
                                                                        "message"],
                                                                    styleSheet:
                                                                        MarkdownStyleSheet(
                                                                            p: TextStyle(
                                                                      fontVariations: [
                                                                        FontVariation(
                                                                          'ROND',
                                                                          100,
                                                                        ),
                                                                        FontVariation
                                                                            .weight(
                                                                          400,
                                                                        ),
                                                                      ],
                                                                    )),
                                                                    onTapLink: (text,
                                                                        href,
                                                                        title) {
                                                                      if (href !=
                                                                          null) {
                                                                        launchUrl(
                                                                          Uri.parse(
                                                                              href),
                                                                          mode:
                                                                              LaunchMode.externalApplication,
                                                                        );
                                                                      }
                                                                    },
                                                                  ),
                                                                )
                                                              ],
                                                            ));
                                                          },
                                                        );
                                                      },
                                                    );
                                                  }
                                                },
                                                title: Text(
                                                  alert.value["header"],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  alert.value["message"]
                                                              .toString()
                                                              .length >
                                                          65
                                                      ? alert.value["message"]
                                                              .toString()
                                                              .substring(
                                                                  0, 65) +
                                                          "..."
                                                      : alert.value["message"],
                                                ),
                                                trailing: Icon(Icons
                                                    .arrow_forward_rounded),
                                              ),
                                            ),
                                          )
                                    ],
                                  ),
                                );
                              }),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 5, 0),
                            child: Text(
                              "Favourites:",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28.0),
                            ),
                            margin: EdgeInsets.fromLTRB(0, 5, 0, 5),
                            child: Favourites(
                              key: ValueKey(count),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 5, 0),
                            child: Text(
                              "Nearby:",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          Container(
                            child: Nearby(
                              key: ValueKey(count),
                            ),
                          ),
                          SizedBox(
                            height: 65,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        count++;
                      });
                    },
                    child: Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isNFCSupported)
                  Hero(
                    tag: 'ezlinkHero', // Shared tag
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(200),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(200),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => const CepasReader()));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.credit_card_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  "EZ-Link",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isNFCSupported) SizedBox(width: 8),
                if (isNFCSupported) Expanded(child: SearchBarWidget()),
                if (!isNFCSupported) SearchBarWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
