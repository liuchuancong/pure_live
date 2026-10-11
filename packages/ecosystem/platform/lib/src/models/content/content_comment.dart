// Module: lib/src/models/content/content_comment.dart
// Purpose: One comment on a piece of content, and the count of what it has under it.
// Author: liuchuancong
// Created: 2026-10-11
//
// Spec: docs/contracts/capability-contract.md section 1 (comment capability). Replies are counted here and
// fetched separately, because a comment page that flattened its threads is how a two-level discussion shows up
// as a hundred top-level rows - and the platform's own endpoints fetch them on demand anyway.

import '../../support/json.dart';

/// One comment as a source reported it.
final class ContentComment {
  const ContentComment({
    required this.id,
    required this.text,
    required this.author,
    this.at,
    this.likes,
    this.replyCount,
    this.parentId,
    this.avatar,
    this.isPinned = false,
    this.extra = const <String, Object?>{},
  });

  factory ContentComment.fromJson(Map<String, Object?> json) => ContentComment(
    id: requireString(json, 'id', 'content_comment'),
    text: json['text'] is String ? json['text']! as String : '',
    author: json['author'] is String ? json['author']! as String : '',
    at: parseUtc(json['at']),
    likes: _intOrNull(json['likes']),
    replyCount: _intOrNull(json['replyCount']),
    parentId: json['parentId'] is String ? json['parentId']! as String : null,
    avatar: json['avatar'] is String ? json['avatar']! as String : null,
    isPinned: json['isPinned'] as bool? ?? false,
    extra: asObjectMap(json['extra']),
  );

  /// Stable within the source. A comment list that renumbers between pages duplicates or loses rows on reload,
  /// which is why the id is required and not derived from position.
  final String id;
  final String text;
  final String author;
  final DateTime? at;
  final int? likes;

  /// How many replies exist, not the replies themselves.
  final int? replyCount;

  /// Set when this row is a reply; top-level comments leave it null.
  final String? parentId;
  final String? avatar;
  final bool isPinned;
  final Map<String, Object?> extra;

  bool get isReply => parentId != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'text': text,
    'author': author,
    if (at != null) 'at': formatUtc(at),
    if (likes != null) 'likes': likes,
    if (replyCount != null) 'replyCount': replyCount,
    if (parentId != null) 'parentId': parentId,
    if (avatar != null) 'avatar': avatar,
    if (isPinned) 'isPinned': true,
    if (extra.isNotEmpty) 'extra': extra,
  };

  @override
  String toString() => 'ContentComment($id $author)';
}

int? _intOrNull(Object? value) => switch (value) {
  final num number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};
