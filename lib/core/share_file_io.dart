// Hisaab Kitaab — share a text file on mobile (v7.4).
//
// The system share sheet (share_plus): the user picks
// WhatsApp, Drive, email, Files — whatever is installed.

import 'dart:convert';

import 'package:share_plus/share_plus.dart';

Future<void> shareTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          utf8.encode(content),
          name: fileName,
          mimeType: mimeType,
        ),
      ],
    ),
  );
}
