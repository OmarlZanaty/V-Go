/// Driver profile as returned by `Driver/driver/{id}` (DriverDTO).
class DriverProfileModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? gender;
  final String? license;
  final String? scooterLicense;

  /// Normalized to 'Gasoline' | 'Electric' | '' regardless of whether the API
  /// serializes the enum as a number or a string.
  final String scooterType;
  final int tripCount;
  final double? rate;
  final String? profilePicture;

  const DriverProfileModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.gender,
    this.license,
    this.scooterLicense,
    this.scooterType = '',
    this.tripCount = 0,
    this.rate,
    this.profilePicture,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> j) {
    return DriverProfileModel(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      phone: j['phoneNumber']?.toString(),
      email: j['email']?.toString(),
      gender: j['gender']?.toString(),
      license: j['license']?.toString(),
      scooterLicense: j['scooterLicense']?.toString(),
      scooterType: _scooterType(j['scooterType']),
      tripCount: _toInt(j['tripCount']),
      rate: _toDouble(j['rate']),
      profilePicture: j['profilePicture']?.toString(),
    );
  }

  String get scooterTypeAr {
    switch (scooterType) {
      case 'Electric':
        return 'كهربائي';
      case 'Gasoline':
        return 'بنزين';
      default:
        return scooterType.isEmpty ? 'غير محدد' : scooterType;
    }
  }

  String get genderAr {
    switch (gender) {
      case 'Male':
        return 'ذكر';
      case 'Female':
        return 'أنثى';
      default:
        return gender == null || gender!.isEmpty ? '—' : gender!;
    }
  }

  static String _scooterType(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toInt() == 1 ? 'Electric' : 'Gasoline';
    final s = v.toString();
    if (s == '0') return 'Gasoline';
    if (s == '1') return 'Electric';
    return s;
  }

  static int _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  static double? _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
}
