import 'dart:typed_data';

import 'package:sgbus/scripts/ezlink_reader/ezlink_merchant_info.dart';

class CepasPurse {
  final String can;
  final double balance;
  final DateTime expiryDate;

  CepasPurse(
      {required this.can, required this.balance, required this.expiryDate});

  factory CepasPurse.fromBytes(Uint8List data) {
    // Balance: 3-byte signed integer at Offset 2, 3, 4
    int b1 = data[2] & 0xFF;
    int b2 = data[3] & 0xFF;
    int b3 = data[4] & 0xFF;
    int balanceRaw = (b1 << 16) | (b2 << 8) | b3;

    // Use your proven subtraction method for Dart sign extension
    if ((balanceRaw & 0x800000) != 0) {
      balanceRaw -= 0x1000000;
    }

    // CAN: 8 bytes starting at Offset 8
    String can = data
        .sublist(8, 16)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();

    // Expiry: 2 bytes at Offset 24, 25 (Days since Jan 1, 1995)
    int expiryDays = ((data[24] & 0xFF) << 8) | (data[25] & 0xFF);
    DateTime expiry = DateTime.fromMillisecondsSinceEpoch(
            (expiryDays * 86400 + 788947200) * 1000,
            isUtc: true)
        .toLocal();

    return CepasPurse(
        can: can, balance: balanceRaw / 100.0, expiryDate: expiry);
  }
}

class CepasTransaction {
  final String category;
  final String type;
  double amount;
  final DateTime timestamp;
  final String readableLocation;

  CepasTransaction({
    required this.category,
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.readableLocation,
  });

  factory CepasTransaction.fromBytes(Uint8List data) {
    // 1. Amount Parsing (Subtraction method)
    int b1 = data[1] & 0xFF;
    int b2 = data[2] & 0xFF;
    int b3 = data[3] & 0xFF;
    int amountRaw = (b1 << 16) | (b2 << 8) | b3;
    if ((amountRaw & 0x800000) != 0) amountRaw -= 0x1000000;
    double finalAmount = amountRaw.abs() / 100.0;

    // 2. FIXED Timestamp Parsing
    // The base constant 788889600 is "1995-01-01 00:00:00 SGT" expressed in UTC seconds.
    int seconds = ((data[4] & 0xFF) << 24) |
        ((data[5] & 0xFF) << 16) |
        ((data[6] & 0xFF) << 8) |
        (data[7] & 0xFF);

    DateTime finalTime = DateTime.fromMillisecondsSinceEpoch(
            (seconds + 788889600) * 1000,
            isUtc: true)
        .toLocal();

    // 3. Metadata and Cleaning
    String typeStr = (data[0] == 49)
        ? "BUS"
        : (data[0] == 48)
            ? "MRT"
            : "TOPUP";
    String rawUser = String.fromCharCodes(data.sublist(8, 16));
    String cleanUser = _cleanString(rawUser);

    // 4. Category and Location Logic
    String finalCategory = _getInitialCategory(data[0]);
    String finalLocation = cleanUser;

    if (cleanUser.contains('-')) {
      finalLocation = _translateMrt(cleanUser);
      finalCategory = "Transport";
    } else {
      final busMatch = RegExp(r'^(BUS|SVC)\s*(.*)$').firstMatch(cleanUser);
      if (busMatch != null) {
        finalLocation = "Bus ${busMatch.group(2)!.trim()}";
        finalCategory = "Transport";
      } else {
        var lookup = _lookupMerchant(cleanUser);
        finalLocation = lookup['name'] ?? cleanUser;
        if (lookup['category'] != null) finalCategory = lookup['category']!;
      }
    }

    return CepasTransaction(
      category: finalCategory,
      type: typeStr,
      amount: finalAmount,
      timestamp: finalTime,
      readableLocation: finalLocation,
    );
  }

  // Mimics SingCard's getAsciiString to remove null bytes and control codes
  static String _cleanString(String str) {
    return str.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
  }

  static String _getInitialCategory(int typeByte) {
    if (typeByte == 48 || typeByte == -123) return "Transport";
    if (typeByte == 49 || typeByte == -122) return "Transport";
    if ([3, 117, -126, 121, 2].contains(typeByte)) return "Top-up";
    if ([7, 8, 9, 59].contains(typeByte)) return "Motoring";
    return "Others";
  }

  static Map<String, String?> _lookupMerchant(String raw) {
    String key = raw;
    final suffixes = [" GTM", " PSC", " TUM", " AVM", " TSO", " TUK"];
    for (var s in suffixes) {
      if (raw.endsWith(s)) {
        key = raw.substring(0, raw.length - s.length).trim();
        break;
      }
    }

    var data = EzLinkData.merchants[key];
    if (data != null)
      return {'name': data['name'], 'category': data['category']};

    var station = EzLinkData.stations[key];
    if (station != null)
      return {'name': station['name'], 'category': 'Transport'};

    return {'name': raw, 'category': null};
  }

  static String _translateMrt(String raw) {
    List<String> codes = raw.split('-');
    String start =
        EzLinkData.stations[codes[0].trim()]?['name'] ?? codes[0].trim();
    String end =
        EzLinkData.stations[codes[1].trim()]?['name'] ?? codes[1].trim();
    return "$start to $end";
  }
}
