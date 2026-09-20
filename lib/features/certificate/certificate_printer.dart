library;

/// Opens the membership certificate in a new browser tab and asks the browser
/// to print it. The person can print on paper or pick "Save as PDF"
/// (docs/MEMBERSHIP_CERTIFICATE_PLAN.md §2).
///
/// The browser is what renders the sheet, because the Dart `pdf` package does
/// not shape Devanagari correctly and the whole certificate is in Hindi.
///
/// Returns false when nothing could be opened — on a non-web build, or when
/// the browser blocked the pop-up.
export 'certificate_printer_stub.dart'
    if (dart.library.js_interop) 'certificate_printer_web.dart';
