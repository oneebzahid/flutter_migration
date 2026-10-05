import 'settings_datasource.dart';

class MockSettingsDataSource implements SettingsDataSource {
  MockSettingsDataSource({this.latency = const Duration(milliseconds: 300)});

  final Duration latency;
  String _currency = 'PKR';

  @override
  Future<String> getCurrency() async {
    await Future<void>.delayed(latency);
    return _currency;
  }

  @override
  Future<void> setCurrency(String code) async {
    await Future<void>.delayed(latency);
    _currency = code;
  }
}
