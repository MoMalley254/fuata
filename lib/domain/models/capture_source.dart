/// design.md CAPTURE_SOURCE: one app whose notifications Fuata is allowed
/// to read (US-10). The set of *enabled* sources is the allow-list —
/// anything posted by a package that isn't in it is discarded the moment
/// it arrives and never stored (requirements.md, Privacy row).
///
/// Turning an app off keeps the row and flips [enabled] rather than
/// deleting it: `Templates.captureSourceId` references this table, and a
/// delete would trip the foreign key the moment a rule is tied to an app.
class CaptureSource {
  final String id;
  final String packageName;
  final String displayName;
  final bool enabled;

  const CaptureSource({
    required this.id,
    required this.packageName,
    required this.displayName,
    this.enabled = true,
  });

  // One row per package, by construction: the id is derived from the
  /// package name, so saving the same app twice is an upsert rather than a
  /// duplicate (the table has no unique index on `packageName`, and
  /// changing a table definition without a migration is off the table).
  static String idFor(String packageName) => 'src_$packageName';

  CaptureSource copyWith({String? displayName, bool? enabled}) {
    return CaptureSource(
      id: id,
      packageName: packageName,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
    );
  }
}