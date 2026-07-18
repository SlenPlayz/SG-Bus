import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sgbus/env.dart';

class FloatingAd extends StatefulWidget {
  final EdgeInsetsGeometry margin;

  const FloatingAd({
    Key? key,
    required this.margin,
  }) : super(key: key);

  @override
  _FloatingAdState createState() => _FloatingAdState();
}

class _FloatingAdState extends State<FloatingAd> {
  BannerAd? _ad;
  bool _isLoaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (adsEnabled) {
      _loadAd();
    } else {
      _hasError = true;
    }
  }

  void _loadAd() {
    _ad = BannerAd(
      adUnitId: kReleaseMode ? bannerUnitID : testBannerUnitID,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, err) async {
          ad.dispose();
          if (mounted) setState(() => _hasError = true);
          if (!kReleaseMode) print(err);
          await Sentry.captureException(err, stackTrace: StackTrace.current);
        },
      ),
    );
    _ad!.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || !adsEnabled) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: _isLoaded && _ad != null
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surface.withOpacity(0.75),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        width: AdSize.banner.width.toDouble(),
        height: AdSize.banner.height.toDouble(),
        child: _isLoaded && _ad != null
            ? AdWidget(ad: _ad!)
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 30,
                        width: 30,
                        child: ExpressiveLoadingIndicator(),
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Loading Ad...",
                        style: TextStyle(
                          fontVariations: [
                            FontVariation('ROND', 100),
                            FontVariation.width(120),
                            FontVariation.weight(1000)
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
