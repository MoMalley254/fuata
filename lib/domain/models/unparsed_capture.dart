/// design.md's `unparsed_capture`: a message the parser couldn't read,
/// kept only long enough for the review inbox's "Couldn't read these"
/// list to offer "Teach me" (US-11), then deleted by the person or
/// auto-purged after 7 days. Raw text is stored here *by design* — that
/// is the whole point of the list — unlike transactions, where rawText
/// is opt-in only (ADR-009).
class UnparsedCapture {
  final String id;
  final DateTime receivedAt;
  // 'shared' for the share/paste paths (#21); the notification listener
  // (#22) writes the real Android package name it saw the message in.
  final String sourcePackage;
  final String rawText;

  const UnparsedCapture({
    required this.id,
    required this.receivedAt,
    required this.sourcePackage,
    required this.rawText,
  });
}