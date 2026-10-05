/// Raw settings source (Firestore/Supabase/in-memory). Throws typed exceptions.
abstract interface class SettingsDataSource {
  Future<String> getCurrency();
  Future<void> setCurrency(String code);
}
