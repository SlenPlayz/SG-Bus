import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AlertWebviewPage extends StatefulWidget {
  const AlertWebviewPage(
      {Key? key,
      required this.header,
      required this.message,
      required this.link,
      required this.linkDesc})
      : super(key: key);
  final header;
  final message;
  final link;
  final linkDesc;

  @override
  State<AlertWebviewPage> createState() => _AlertWebviewPageState();
}

class _AlertWebviewPageState extends State<AlertWebviewPage> {
  late WebViewController controller;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            setState(() {
              loaded = true;
            });
          },
          // onHttpError: (HttpResponseError error) {},
          // onWebResourceError: (WebResourceError error) {},
          // onNavigationRequest: (NavigationRequest request) {
          //   if (request.url.startsWith('https://www.youtube.com/')) {
          //     return NavigationDecision.prevent;
          //   }
          //   return NavigationDecision.navigate;
          // },
        ),
      )
      ..loadRequest(Uri.parse(widget.link));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // bottom: PreferredSize(
        //   preferredSize: Size.fromHeight(20),
        //   child:
        // ),
        actions: [
          IconButton(
              onPressed: () {
                launchUrl(
                  Uri.parse(widget.link),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: Icon(Icons.open_in_browser_rounded)),
          IconButton(
              onPressed: controller.reload, icon: Icon(Icons.refresh_rounded)),
        ],
      ),
      body: (controller != null && loaded)
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.header,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: WebViewWidget(controller: controller),
                ),
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Container(
                    height: 130,
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        child: MarkdownBody(
                          data: widget.message,
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              launchUrl(Uri.parse(href),
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                      thumbVisibility: true,
                    ),
                  ),
                )
              ],
            )
          : Center(
              child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LoadingIndicatorM3E(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(widget.linkDesc),
                  )
                ],
              ),
            )),
    );
  }
}
