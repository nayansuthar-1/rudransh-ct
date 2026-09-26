import 'certificate_data.dart';

/// Non-web builds — widget tests, a desktop debug run. There is no browser to
/// open a tab in, so nothing is printed and the caller shows a message.
///
/// The trust only ships the web build, so this never runs in production.
Future<bool> openCertificateForPrint(
  CertificateData data, {
  CertificateData? pair,
}) async =>
    false;
