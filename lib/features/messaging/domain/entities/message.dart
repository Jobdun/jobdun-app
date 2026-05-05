import 'package:equatable/equatable.dart';

class Message extends Equatable {
  const Message({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String jobId;
  final String senderId;
  final String receiverId;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, jobId, senderId, receiverId, createdAt];
}
