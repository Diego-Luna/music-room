// * Stub for dart:io Platform — used on web where dart:io is unavailable.
// * native platforms and this file on web, keeping kIsWeb ? false as guard.
class Platform {
  // ! This class is never reached on web because _isTest is always false
  // ! when kIsWeb is true. It exists only to satisfy the type system.
  static const Map<String, String> environment = {};
}
