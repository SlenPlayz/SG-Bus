import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sgbus/pages/alert_webview_page.dart';
import 'package:url_launcher/url_launcher.dart';

void showAlertDetails(BuildContext context, dynamic alert) {
  if (alert == null) return;
  if (alert["type"] == "webview") {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => AlertWebviewPage(
            header: alert["header"],
            message: alert["message"],
            link: alert["link"],
            linkDesc: alert["linkDesc"])));
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.2,
          maxChildSize: 0.85,
          shouldCloseOnMinExtent: true,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28.0)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            alert["header"]?.toString() ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontVariations: const [
                                FontVariation('ROND', 100),
                                FontVariation.width(100),
                                FontVariation.weight(1000),
                              ],
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 32.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: MarkdownBody(
                            data: alert["message"]?.toString() ?? '',
                            fitContent: false,
                            styleSheet: MarkdownStyleSheet.fromTheme(
                                    Theme.of(context))
                                .copyWith(
                              p: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                fontVariations: const [
                                  FontVariation('ROND', 100),
                                  FontVariation.weight(400),
                                ],
                              ),
                              textAlign: WrapAlignment.start,
                              h1Align: WrapAlignment.start,
                              h2Align: WrapAlignment.start,
                              h3Align: WrapAlignment.start,
                              unorderedListAlign: WrapAlignment.start,
                              orderedListAlign: WrapAlignment.start,
                              blockquoteAlign: WrapAlignment.start,
                              codeblockAlign: WrapAlignment.start,
                            ),
                            onTapLink: (text, href, title) {
                              if (href != null) {
                                launchUrl(
                                  Uri.parse(href),
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
