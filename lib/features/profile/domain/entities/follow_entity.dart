enum FollowStatus {
  pending,
  accepted,
  rejected,
}

class FollowEntity {
  final String id;
  final String followerId;
  final String followingId;
  final FollowStatus status;
  final DateTime createdAt;

  const FollowEntity({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.status,
    required this.createdAt,
  });

  factory FollowEntity.fromMap(Map<String, dynamic> map) {
    final statusString = map['status'] as String;
    FollowStatus parsedStatus = FollowStatus.pending;
    if (statusString == 'accepted') parsedStatus = FollowStatus.accepted;
    if (statusString == 'rejected') parsedStatus = FollowStatus.rejected;

    return FollowEntity(
      id: map['id'] as String,
      followerId: map['follower_id'] as String,
      followingId: map['following_id'] as String,
      status: parsedStatus,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
