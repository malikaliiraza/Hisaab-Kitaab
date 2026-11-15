// Hisaab Kitaab — share a text file (v7.4).
//
// One call, two platforms: on the web the file downloads in
// the browser; on a phone it opens the system share sheet
// (share_plus). The platform file is picked by conditional
// import — dart:html must never be compiled into a mobile
// build, and share_plus file-sharing must never run on web.

import 'share_file_io.dart' if (dart.library.html) 'share_file_web.dart'
    as platform;

/// Share [content] as a file called [fileName]: a browser
/// download on web, the share sheet on mobile.
Future<void> shareTextFile({
  required String fileName,
  required String content,
  required String mimeType,
}) {
  return platform.shareTextFile(
    fileName: fileName,
    content: content,
    mimeType: mimeType,
  );
}
