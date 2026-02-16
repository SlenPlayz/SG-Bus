import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:hex/hex.dart';
import 'package:sgbus/scripts/cepasManager.dart';
import 'package:skeletonizer/skeletonizer.dart';

String insertCepasCanSpaces(String input) {
  // First, remove any existing spaces to ensure consistent formatting
  final cleanInput = input.replaceAll(' ', '');

  // Use a regular expression to find groups of up to 4 characters (.{1,4})
  // and add a space after each group
  return cleanInput
      .replaceAllMapped(
        RegExp(r'.{1,4}'),
        (Match match) => '${match.group(0)} ',
      )
      .trim(); // Trim the trailing space from the end of the string
}

class CepasReader extends StatefulWidget {
  const CepasReader({Key? key}) : super(key: key);

  @override
  _CepasReaderState createState() => _CepasReaderState();
}

class _CepasReaderState extends State<CepasReader> {
  bool isTransactionRead = false;
  bool isBalanceRead = false;
  bool hasNFCExchangeFinished = false;

  bool timeoutOccurred = false;
  String? CAN;
  double? balance;
  DateTime? expiryDate;

  List<CepasTransaction> transactions = [];

  bool errorOccured = false;
  bool errorRetryable = false;
  String? errorMSG;

  Future<void> readCepasCard() async {
    setState(() {
      isTransactionRead = false;
      timeoutOccurred = false;
      errorOccured = false;
      errorMSG = null;
      errorRetryable = false;
    });
    try {
      var nfcAvaliable = await FlutterNfcKit.nfcAvailability;

      if (nfcAvaliable == NFCAvailability.disabled) {
        errorMSG =
            "NFC is currently disabled. Please enable NFC to be able to read your card balance.";
        setState(() {
          errorRetryable = true;
          errorOccured = true;
        });
        return;
      }

      if (nfcAvaliable == NFCAvailability.disabled) {
        errorMSG =
            "This feature requires an NFC reader which your device does not have.";
        setState(() {
          errorOccured = true;
        });
        return;
      }

      NFCTag tag = await FlutterNfcKit.poll(timeout: Duration(seconds: 20));

      // 1. Handshake to unlock the card applet
      await FlutterNfcKit.transceive("00A4040008A00000034100010100");
      await FlutterNfcKit.transceive("00A40000023F00");
      await FlutterNfcKit.transceive("00A40000024000");

      // 2. Read the master Purse block
      String purseHex = await FlutterNfcKit.transceive("903203000000");

      if (purseHex.length > 20 && !purseHex.startsWith("6")) {
        Uint8List pData = Uint8List.fromList(HEX.decode(purseHex));
        var purse = CepasPurse.fromBytes(pData);

        print("--- CARD SUMMARY ---");
        print("CAN: ${purse.can}");
        print("Balance: \$${purse.balance.toStringAsFixed(2)}");
        print(
            "Expiry: ${purse.expiryDate.day}/${purse.expiryDate.month}/${purse.expiryDate.year}");

        CAN = purse.can;
        balance = purse.balance;
        expiryDate = purse.expiryDate;

        setState(() {
          isBalanceRead = true;
          CAN = purse.can;
          balance = purse.balance;
          expiryDate = purse.expiryDate;
        });

        // 3. Get the record count from Offset 40
        int recordCount = pData[40] & 0xFF;
        print("Fetching $recordCount recent trips...");

        List<CepasTransaction> history = [];
        // Read in blocks of 15 (240 bytes) to stay within the APDU limit
        for (int offset = 0; offset < recordCount; offset += 15) {
          int toRead =
              (recordCount - offset > 15) ? 15 : (recordCount - offset);
          String hexOffset = offset.toRadixString(16).padLeft(2, '0');
          String hexLen = (toRead * 16).toRadixString(16).padLeft(2, '0');

          String res =
              await FlutterNfcKit.transceive("9032030001$hexOffset$hexLen");
          if (res.length > 20 && !res.startsWith("6")) {
            Uint8List hData = Uint8List.fromList(HEX.decode(res));
            for (int j = 0; j < hData.length - 16; j += 16) {
              history.add(CepasTransaction.fromBytes(hData.sublist(j, j + 16)));
            }
          }
        }

        print("--- TRANSACTION HISTORY ---");

        for (var tx in history.asMap().entries) {
          var index = tx.key;
          var previousIndex = tx.key + 1;
          if (tx.value.type == "TOPUP" &&
              tx.value.readableLocation.substring(0, 3) == "Bus") {
            print("Invalid TOPUP");
            history[previousIndex].amount -= tx.value.amount;
          } else {
            transactions.add(tx.value);
          }
        }

        for (var tx in history) {
          if (tx.timestamp.year > 2000) {
            // Using padRight and toStringAsFixed for a clean table look
            String date =
                "${tx.timestamp.day}/${tx.timestamp.month}".padRight(5);
            String type = tx.type.padRight(5);
            String amt = "\$${tx.amount.toStringAsFixed(2)}".padRight(7);

            // OUTPUT THE TRANSLATED LOCATION HERE
            print("$date | $type | $amt | ${tx.readableLocation}");
          }
        }

        setState(() {
          isTransactionRead = true;
          CAN = purse.can;
          balance = purse.balance;
          expiryDate = purse.expiryDate;
        });
      }
    } catch (e) {
      print("NFC Error: $e");
      if (e.toString().contains("timeout")) {
        setState(() {
          timeoutOccurred = true;
        });
      }
    } finally {
      setState(() {
        hasNFCExchangeFinished = true;
      });
      await FlutterNfcKit.finish();
    }
  }

  @override
  void initState() {
    super.initState();
    readCepasCard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'ezlinkHero', // Same tag as home.dart
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              "EZ-Link Reader",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(
                        "Beta feature",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      icon: Icon(Icons.science_rounded),
                      content: Text(
                        "This feature is currently still under developement and may not always work as intended. Displayed values should be correct but the app may be unable to read transaction history sometimes.",
                        textAlign: TextAlign.center,
                      ),
                      actionsAlignment: MainAxisAlignment.center,
                      actions: [
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          label: Text("Dismiss"),
                          icon: Icon(Icons.exit_to_app_rounded),
                        )
                      ],
                    );
                  });
            },
            icon: Row(children: [
              Icon(
                Icons.science_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              Container(
                width: 5,
              ),
              Text(
                "BETA",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            ]),
          ),
        ],
      ),
      body: Stack(
        children: [
          errorOccured
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(50.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 10.0),
                          child: Icon(Icons.warning_rounded,
                              size: 50,
                              color: Theme.of(context).colorScheme.error),
                        ),
                        Text(
                          errorMSG ?? "An unknown error occured.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        if (errorRetryable)
                          FilledButton.icon(
                            onPressed: readCepasCard,
                            label: Text("Retry"),
                            icon: Icon(Icons.refresh_rounded),
                          )
                      ],
                    ),
                  ),
                )
              : AnimatedAlign(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  alignment: isTransactionRead
                      ? Alignment.topCenter
                      : Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CardUI(
                        isTransactionRead: isTransactionRead,
                        CAN: CAN,
                        balance: balance,
                        expiryDate: expiryDate,
                        isTimeoutOccurred: timeoutOccurred,
                        isBalanceRead: isBalanceRead,
                      ),
                      if (timeoutOccurred && !isTransactionRead)
                        Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: FilledButton.icon(
                              onPressed: readCepasCard,
                              label: Text("Scan Card"),
                              icon: Icon(Icons.tap_and_play),
                            )),
                      Container(),
                      Expanded(
                        child: isBalanceRead &&
                                !isTransactionRead &&
                                hasNFCExchangeFinished
                            ? Expanded(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 500),
                                  opacity: isBalanceRead &&
                                          !isTransactionRead &&
                                          hasNFCExchangeFinished
                                      ? 1.0
                                      : 0.0,
                                  child: Container(
                                    margin: EdgeInsets.only(top: 10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(28.0)),
                                      child: Container(
                                        constraints: BoxConstraints.expand(),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceVariant
                                            .withOpacity(0.3),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.warning_rounded,
                                              size: 64,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                            Container(
                                              height: 10,
                                            ),
                                            Text(
                                              "Transaction history not avaliable",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : AnimatedOpacity(
                                duration: const Duration(milliseconds: 500),
                                opacity: isTransactionRead ? 1.0 : 0.0,
                                child: isTransactionRead
                                    ? TransactionHistoryUI(
                                        transactions: transactions)
                                    : const SizedBox.shrink(),
                              ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

class CardUI extends StatelessWidget {
  const CardUI(
      {Key? key,
      this.CAN,
      this.balance,
      this.expiryDate,
      required this.isTransactionRead,
      required this.isTimeoutOccurred,
      required this.isBalanceRead})
      : super(key: key);
  final String? CAN;
  final double? balance;
  final DateTime? expiryDate;
  final bool isTransactionRead;
  final bool isTimeoutOccurred;
  final bool isBalanceRead;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Skeletonizer(
          enabled: !isBalanceRead,
          enableSwitchAnimation: true,
          child: Card(
            color:
                Theme.of(context).colorScheme.primaryContainer.withAlpha(150),
            elevation: 0,
            child: SizedBox(
              width: 324,
              // height: 204,
              child: Padding(
                padding: const EdgeInsets.all(7.0),
                child: isTimeoutOccurred
                    ? Skeleton.keep(
                        child: Center(
                          child: Text(
                            "NFC Timed out. Took too long to scan. Please click the button below to try again.",
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Skeleton.keep(
                                child: Icon(
                                  Icons.credit_card,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Skeleton.keep(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        "BALANCE:",
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      balance != null
                                          ? "\$" + balance!.toStringAsFixed(2)
                                          : "Error",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                          Skeleton.keep(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                "CAN ID:",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              CAN != null
                                  ? insertCepasCanSpaces(CAN!)
                                  : "ERROR ERROR ERROR ERROR",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          SizedBox(height: 8),
                          Skeleton.keep(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                "EXPIRY:",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              expiryDate != null
                                  ? '${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}'
                                  : "Error",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        if (!isBalanceRead)
          Text("Tap your EZ-Link Card to the back of your phone"),
      ],
    );
  }
}

class TransactionHistoryUI extends StatelessWidget {
  const TransactionHistoryUI({Key? key, this.transactions}) : super(key: key);
  final List<CepasTransaction>? transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions == null || transactions!.isEmpty) {
      return Container();
    }

    return ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(28.0)),
      child: ListView(
        children: [
          for (var tx in transactions!.asMap().entries)
            Container(
              margin: EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft:
                      tx.key == 0 ? Radius.circular(28.0) : Radius.circular(5),
                  topRight:
                      tx.key == 0 ? Radius.circular(28.0) : Radius.circular(5),
                  bottomLeft: tx.key == transactions!.length - 1
                      ? Radius.circular(28.0)
                      : Radius.circular(5),
                  bottomRight: tx.key == transactions!.length - 1
                      ? Radius.circular(28.0)
                      : Radius.circular(5),
                ),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
              ),
              child: ListTile(
                leading: Icon(tx.value.type == "BUS"
                    ? Icons.directions_bus_rounded
                    : tx.value.type == "MRT"
                        ? Icons.train_outlined
                        : tx.value.type == "TOPUP"
                            ? Icons.add_rounded
                            : Icons.swap_vert_rounded),
                title: Text(
                  "${tx.value.type != "BUS" ? tx.value.type + ": " : ""}${tx.value.readableLocation}",
                  style: TextStyle(
                    color: tx.value.type == "TOPUP"
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                // subtitle: Text(
                //     "${tx.value.timestamp.day.toString().padLeft(2, '0')}/${tx.value.timestamp.month.toString().padLeft(2, '0')}"),
                subtitle: Text(
                    "${tx.value.timestamp.day.toString().padLeft(2, '0')}/${tx.value.timestamp.month.toString().padLeft(2, '0')} ${tx.value.timestamp.hour.toString().padLeft(2, '0')}:${tx.value.timestamp.minute.toString().padLeft(2, '0')}"),
                trailing: Text("\$${tx.value.amount.toStringAsFixed(2)}"),
              ),
            ),
        ],
      ),
    );
  }
}
