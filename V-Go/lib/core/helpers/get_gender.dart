String getGender(String? gender) {
    switch (gender) {
      case 'Male':
      case 'male':
        return 'ذكر';
      case 'Female':
      case 'female':
        return 'انثى';
      default:
        return 'غير محدد';
    }
  }

/// Backend wants exactly "Male"/"Female" (UI widgets use lowercase values).
String? apiGender(String? gender) {
  switch (gender?.toLowerCase()) {
    case 'male':
      return 'Male';
    case 'female':
      return 'Female';
    default:
      return null;
  }
}

/// Reads genderConfirmed from a login/user payload (camel or Pascal case).
/// Absent entirely (older backend) => true so nobody gets locked out.
bool parseGenderConfirmed(Map<String, dynamic> json) {
  final v = json.containsKey('genderConfirmed')
      ? json['genderConfirmed']
      : json['GenderConfirmed'];
  if (v == null) {
    return !(json.containsKey('genderConfirmed') ||
        json.containsKey('GenderConfirmed'));
  }
  return v == true;
}
