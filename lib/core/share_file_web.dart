// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Hisaab Kitaab — share a text file on web (v7.4).
//
// The Web Share API cannot be relied on for files, so the
// file simply downloads in the browser — the same result
// the user wants (a file they can keep or forward).

import 'dart:html' as html;

Future<void> shareTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) async {
  final blob = html.Blob([content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = fileName
    ..click();
  html.Url.revokeObjectUrl(url);
}
