# Bundled fonts

| Family in the app | Source | Licence |
| --- | --- | --- |
| `AppSans` | Static Regular/Medium/SemiBold/Bold instances of Google Sans Flex (opsz 18, wdth 100), cut with `fonttools varLib.instancer` | SIL OFL 1.1, `AppSans-OFL.txt` |
| `NotoSansDevanagari` | Static instances of Noto Sans Devanagari (wdth 100) | SIL OFL 1.1, `NotoSansDevanagari-OFL.txt` |
| `YatraOne` | Yatra One, unmodified | SIL OFL 1.1, `YatraOne-OFL.txt` |
| `Arimo` | Static Bold (700) instance of Arimo, as served by Google Fonts | SIL OFL 1.1, `Arimo-OFL.txt` |

The instances are renamed because Google's trademark notice does not allow
modified copies to be called "Google Sans". No affiliation with Google is implied.

Flutter web ignores CSS font links, so the fonts must be bundled here.

Yatra One and Arimo are not Flutter font families. Only the printed membership
certificate uses them — Yatra One for its header, Arimo (metrically the same as
Arial) for the Latin text in that header, as the reference certificate sets it —
and that is an HTML page the browser renders. So they are declared under
`assets:` in `pubspec.yaml` rather than `fonts:`, and no widget draws with them.
