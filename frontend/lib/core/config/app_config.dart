/// Application configuration constants.
/// Replace placeholder values with your actual keys before running.
class AppConfig {
  AppConfig._();

  /// Gemini API key — get one free at https://aistudio.google.com
  static const String geminiApiKey = 'AIzaSyBooKltz6Nh44PKUNY-ZO_urUbggHutUoI';

  /// FastAPI WebSocket base URL (no trailing slash).
  /// For Android emulator use 10.0.2.2, for real device use your LAN IP.
  static const String wsBaseUrl = 'ws://192.168.1.2:8000';

  /// Calorie calculation constants (MET values from Compendium of Physical Activities)
  static const double pushupMetValue = 8.0;
  static const double squatMetValue = 5.0;

  /// Rep-based calorie constants (kcal per rep for a 70 kg person)
  static const double pushupKcalPerRep70kg = 0.36;
  static const double squatKcalPerRep70kg = 0.32;

  /// Default user weight if profile not set (kg)
  static const double defaultWeightKg = 70.0;
}
