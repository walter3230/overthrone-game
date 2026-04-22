// lib/features/research/state/research_slot.dart
class ResearchSlot {
  final String? nodeId; // null means idle
  final int step; // 1..10
  final DateTime? endsAt;
  final bool locked; // for Pass second slot gating
  const ResearchSlot({
    this.nodeId,
    this.step = 1,
    this.endsAt,
    this.locked = false,
  });

  bool get active => nodeId != null && endsAt != null;
  int get remainingSeconds => !active
      ? 0
      : endsAt!.difference(DateTime.now()).inSeconds.clamp(0, 1 << 31);
}
