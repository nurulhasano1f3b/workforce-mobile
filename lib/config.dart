/// App-wide configuration.
///
/// BASE_URL can be overridden at build time:
///   flutter run --dart-define=BASE_URL=http://192.168.1.x:3000
///
/// Emulator default:  http://10.0.2.2:3000
/// Physical device:   use --dart-define with your LAN IP
const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
