/// Reads genderConfirmed from a login/user payload (camel or Pascal case).
/// Absent entirely (older backend) => true so nobody gets locked out.
bool parseGenderConfirmed(Map<String, dynamic> json) {
  final has =
      json.containsKey('genderConfirmed') || json.containsKey('GenderConfirmed');
  if (!has) return true;
  final v = json.containsKey('genderConfirmed')
      ? json['genderConfirmed']
      : json['GenderConfirmed'];
  return v == true;
}
