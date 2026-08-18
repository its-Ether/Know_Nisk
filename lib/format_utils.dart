// Small display helpers shared by the post cards, detail views and the
// profile views counter — number compaction, relative dates and read time.

const List<String> _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Compacts a count the way social feeds do: 999 stays "999", 1234 becomes
/// "1.2K", 12000 becomes "12K", and 1.5M+ uses the M tier.
String formatCount(int count) {
  if (count < 1000) return '$count';
  if (count < 1000000) {
    final k = count / 1000;
    var text = k >= 10
        ? k.round().toString()
        : k.toStringAsFixed(1);
    if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
    return '${text}K';
  }
  final m = count / 1000000;
  var text = m >= 10 ? m.round().toString() : m.toStringAsFixed(1);
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  return '${text}M';
}

/// A compact "how long ago" label: "just now", "5m ago", "3h ago", "2d ago",
/// then a short absolute date ("Aug 16" or "Aug 16, 2025" for another year).
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final sameYear = time.year == reference.year;
  final base = '${_shortMonths[time.month - 1]} ${time.day}';
  return sameYear ? base : '$base, ${time.year}';
}

/// Approximate reading time in minutes (~200 words/min). Returns null for
/// posts under a minute so they don't advertise a "0 min read".
int? readTimeMinutes(String text) {
  final words = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .length;
  final minutes = words / 200;
  if (minutes < 1) return null;
  return minutes.ceil();
}
