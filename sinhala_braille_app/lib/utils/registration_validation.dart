/// Practical ASCII email syntax check; does not verify mailbox ownership.
bool isValidRegistrationEmail(String email) {
  if (email.length > 254) return false;
  final parts = email.split('@');
  if (parts.length != 2) return false;
  final local = parts[0];
  if (local.isEmpty ||
      local.length > 64 ||
      local.startsWith('.') ||
      local.endsWith('.') ||
      local.contains('..')) {
    return false;
  }
  if (!RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$").hasMatch(local)) {
    return false;
  }
  final labels = parts[1].split('.');
  if (labels.length < 2) return false;
  final labelPattern = RegExp(
    r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$',
  );
  return labels.every(labelPattern.hasMatch) &&
      RegExp(r'^[a-zA-Z]{2,63}$').hasMatch(labels.last);
}
