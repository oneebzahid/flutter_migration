/// Per-company branding. Mirrors the React VITE_COMPANY_* values so a different
/// company build only swaps this object (white-label, BR-14).
class CompanyConfig {
  const CompanyConfig({
    required this.nameLine1,
    required this.nameLine2,
    required this.tagline,
    required this.description,
    required this.shortName,
  });

  final String nameLine1;
  final String nameLine2;
  final String tagline;
  final String description;
  final String shortName;

  String get fullName => '$nameLine1 $nameLine2';

  static const CompanyConfig bullion = CompanyConfig(
    nameLine1: 'BULLION',
    nameLine2: 'ELECTRONICS',
    shortName: 'Bullion Electronics',
    tagline: 'Enterprise Finance System',
    description:
        'Secure financial management platform built for enterprise operations, '
        'reporting, branch monitoring and office workflow management across Abu Dhabi.',
  );
}
