// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fleet Dispatch AI Assistant';

  @override
  String get chatTitle => 'PB Conversational Chatbot';

  @override
  String get online => 'Online';

  @override
  String get howCanIHelp => 'How can I help you today?';

  @override
  String get askAbout =>
      'Ask questions about dispatch, waybills, contractors, and routes';

  @override
  String get typeMessage => 'Type your message...';

  @override
  String get clearChat => 'Clear Chat';

  @override
  String get send => 'Send';

  @override
  String get showTable => 'Show Table';

  @override
  String get showChart => 'Show Chart';

  @override
  String get downloadCsv => 'CSV';

  @override
  String get selectOption => 'Please select an option:';

  @override
  String get selectDataSource => 'Please select a data source:';

  @override
  String get planning => 'Planning...';

  @override
  String get retrievingDocs => 'Retrieving documents...';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get errorConnect =>
      'Unable to connect to the server. Please check your internet connection.';

  @override
  String get errorServer =>
      'The server is temporarily unavailable. Please try again.';

  @override
  String showingRows(int shown, int total) {
    return 'Showing $shown of $total rows';
  }

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get statistics => 'Statistics';

  @override
  String get queriesProcessed => 'Queries Processed';

  @override
  String get userSatisfaction => 'User Satisfaction';

  @override
  String get avgResponseTime => 'Avg Response Time';

  @override
  String get back => 'Back';

  @override
  String get noMessages => 'No messages yet';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get security => 'Security';

  @override
  String get pinLock => 'PIN Lock';

  @override
  String get pinEnabled => 'Enabled';

  @override
  String get pinDisabled => 'Disabled';

  @override
  String get biometricLogin => 'Biometric Login';

  @override
  String get biometricEnabled => 'Fingerprint / Face ID enabled';

  @override
  String get changePin => 'Change PIN';

  @override
  String get enterPin => 'Enter your PIN to continue';

  @override
  String get createPin => 'Create a PIN';

  @override
  String get pinHint => 'Choose a 4-6 digit PIN to secure the app.';

  @override
  String get confirmPin => 'Confirm PIN';

  @override
  String get setPin => 'Set PIN';

  @override
  String get pinTooShort => 'PIN must be at least 4 digits.';

  @override
  String get pinMismatch => 'PINs do not match. Please try again.';

  @override
  String get incorrectPin => 'Incorrect PIN.';

  @override
  String attemptsRemaining(int count) {
    return '$count attempts remaining.';
  }

  @override
  String get accountLocked => 'Account locked. Too many failed attempts.';

  @override
  String get useBiometrics => 'Use Biometrics';

  @override
  String get capabilities => 'Capabilities';

  @override
  String get routeDistribution => 'Route Distribution';

  @override
  String get shareMessage => 'Share Message';

  @override
  String get shareChart => 'Share Chart';

  @override
  String get voiceInput => 'Voice Input';

  @override
  String get listening => 'Listening...';

  @override
  String get speechNotAvailable =>
      'Speech recognition not available on this device.';

  @override
  String get cachedResponse => 'Cached response (offline)';

  @override
  String get offlineMode => 'Offline Mode';

  @override
  String get login => 'Login';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign In';

  @override
  String get invalidCredentials => 'Invalid username or password.';

  @override
  String get logout => 'Logout';
}
