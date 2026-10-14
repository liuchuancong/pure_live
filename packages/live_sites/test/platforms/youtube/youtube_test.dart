import 'dart:convert';

// The test doubles spell their class name in their one constructor; the
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_endpoints.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_http.dart';
import 'package:live_sites/src/platforms/youtube/capabilities/youtube_link_resolver.dart';
import 'package:live_sites/src/platforms/youtube/danmaku/youtube_danmaku_codec.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_play_parser.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_room_parser.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';
import 'package:test/test.dart';

const _videoId = 'dQw4w9WgXcQ';
const _channelId = 'UCabcdefghijklmnopqrstuv';

/// Answers every request from [onSend].
final class _FakeHttp implements LiveHttp {
  _FakeHttp(this.onSend);

  final LiveResponse Function(LiveRequest request) onSend;

  @override
  Future<LiveResponse> send(LiveRequest request) async => onSend(request);

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// A [LiveResponse] with [status] and [body] as UTF-8 text.
LiveResponse _resp(int status, String body) =>
    LiveResponse(statusCode: status, headers: const {}, bodyBytes: utf8.encode(body));

/// A site whose InnerTube calls all answer [body].
YoutubeSite _site(String body) => YoutubeSite(http: YouTubeHttp(_FakeHttp((_) => _resp(200, body))));

/// The right value of an [Either] (throws when it is a left).
T _right<T>(Either<Object?, T> either) => either.match((left) => throw StateError('$left'), (right) => right);

void main() {
  group('room (player + next)', () {
    test('builds a live room, viewer count and first chat continuation', () {
      final player = jsonEncode({
        'playabilityStatus': {'status': 'OK'},
        'videoDetails': {
          'videoId': _videoId,
          'title': 'Live Title',
          'author': 'Chan',
          'externalChannelId': _channelId,
          'isLive': true,
          'thumbnail': {
            'thumbnails': [
              {'url': '//i.ytimg.com/vi/1.jpg'},
              {'url': 'https://i.ytimg.com/vi/maxres.jpg'},
            ],
          },
        },
        'microformat': {
          'playerMicroformatRenderer': {
            'liveBroadcastDetails': {'isLiveNow': true, 'startTimestamp': '2026-09-26T17:00:00-07:00'},
          },
        },
        'streamingData': {
          'hlsManifestUrl': 'https://manifest.googlevideo.com/hls/master.m3u8?expire=1',
          'formats': <Object?>[],
        },
      });
      final next = jsonEncode({
        'contents': {
          'videoPrimaryInfoRenderer': {
            'viewCount': {
              'videoViewCount': {
                'viewCountText': {
                  'runs': [
                    {'text': '1,234 watching'},
                  ],
                },
              },
            },
          },
        },
        'engagementPanels': [
          {
            'liveChatRenderer': {
              'continuations': [
                {
                  'timedContinuationData': {'continuation': 'TOKEN', 'timeoutMs': 5000},
                },
              ],
            },
          },
        ],
      });
      final parse = YoutubeRoomParser.room(player, next, requestedId: _channelId);
      expect(parse.room.content.title, 'Live Title');
      expect(parse.room.anchor?.name, 'Chan');
      expect(parse.room.roomId, _channelId);
      expect(parse.room.broadcast.isLiveNow, isTrue);
      expect(parse.room.audience.onlineViewers, 1234);
      expect(parse.room.content.coverUrl, 'https://i.ytimg.com/vi/maxres.jpg');
      expect(parse.videoId, _videoId);
      expect(parse.continuation, 'TOKEN');
      expect(parse.timeoutMs, 5000);
      expect(parse.isReplay, isFalse);
    });

    test('LIVE_STREAM_OFFLINE is an offline room, not an error', () {
      final player = jsonEncode({
        'playabilityStatus': {'status': 'LIVE_STREAM_OFFLINE'},
        'videoDetails': {'videoId': _videoId, 'title': 'Scheduled', 'externalChannelId': _channelId, 'isLive': false},
      });
      final parse = YoutubeRoomParser.room(player, '{}', requestedId: _channelId);
      expect(parse.room.broadcast.isLiveNow, isFalse);
    });

    test('LOGIN_REQUIRED playability is a risk-control failure', () {
      final player = jsonEncode({
        'playabilityStatus': {'status': 'LOGIN_REQUIRED', 'reason': 'Sign in'},
        'videoDetails': {'videoId': _videoId},
      });
      expect(
        () => YoutubeRoomParser.room(player, '{}', requestedId: _videoId),
        throwsA(isA<YouTubeFailure>().having((f) => f.kind, 'kind', YoutubeFailureKind.riskControl)),
      );
    });
  });

  group('get_live_chat actions', () {
    test('parses chat with an emoji, super chat, gift and retraction', () {
      final body = jsonDecode(
        jsonEncode({
          'continuationContents': {
            'liveChatContinuation': {
              'actions': [
                {
                  'addChatItemAction': {
                    'item': {
                      'liveChatTextMessageRenderer': {
                        'authorName': {'simpleText': 'Alice'},
                        'authorExternalChannelId': 'UCAAAAAAAAAAAAAAAAAAAAAA',
                        'id': 'm1',
                        'timestampUsec': '1727380000000000',
                        'message': {
                          'runs': [
                            {'text': 'hi '},
                            {
                              'emoji': {
                                'emojiId': '😀',
                                'shortcuts': [':smile:', '🙂'],
                                'image': {
                                  'thumbnails': [
                                    {'url': '//yt3.emoji/1.png'},
                                  ],
                                },
                              },
                            },
                          ],
                        },
                      },
                    },
                  },
                },
                {
                  'addChatItemAction': {
                    'item': {
                      'liveChatPaidMessageRenderer': {
                        'purchaseAmountText': {'simpleText': r'$5.00'},
                        'message': {'simpleText': 'Super!'},
                        'authorName': {'simpleText': 'Bob'},
                        'authorExternalChannelId': 'UCBBBBBBBBBBBBBBBBBBBBBB',
                        'id': 'm2',
                        'timestampUsec': '1727380001000000',
                        'headerBackgroundColor': 10770391,
                      },
                    },
                  },
                },
                {
                  'addChatItemAction': {
                    'item': {
                      'messagePayload': {
                        'giftMessageViewModel': {
                          'id': 'g1',
                          'text': {'content': 'sent a gift'},
                          'authorName': {'content': 'Cara'},
                          'giftImage': {
                            'sources': [
                              {'url': 'https://yt3/gift.png'},
                            ],
                          },
                        },
                      },
                    },
                  },
                },
                {
                  'markChatItemAsDeletedAction': {'targetId': 'm1'},
                },
              ],
              'continuations': [
                {
                  'timedContinuationData': {'continuation': 'NEXT', 'timeoutMs': 3000},
                },
              ],
            },
          },
        }),
      );
      final batch = YoutubeDanmakuCodec.parse(body);
      expect(batch.messages, hasLength(4));
      expect(batch.messages[0].type, LiveMessageType.chat);
      expect(batch.messages[0].text, 'hi');
      expect(batch.messages[0].emotes.single.code, ':smile:');
      expect(batch.messages[0].effectiveSender.userName, 'Alice');
      expect(batch.messages[1].type, LiveMessageType.superChat);
      expect(batch.messages[1].color, LiveMessageColor.numberToColor(10770391));
      final superChat = batch.messages[1].payload! as LiveSuperChatMessage;
      expect(superChat.price.amount, 5); // from "$5.00"
      expect(superChat.price.displayText, r'$5.00');
      expect(superChat.userName, 'Bob');
      expect(superChat.text, 'Super!');
      // The header colour is not a named tier, so the paid message keeps the
      // shortest display (one minute) from its own time.
      expect(superChat.startTime, DateTime.fromMicrosecondsSinceEpoch(1727380001000000, isUtc: true));
      expect(superChat.endTime, superChat.startTime!.add(const Duration(minutes: 1)));
      expect(batch.messages[2].type, LiveMessageType.gift);
      expect(batch.messages[2].payload, isA<LiveGift>());
      expect(batch.messages[2].effectiveSender.userName, 'Cara');
      expect((batch.messages[3].payload! as LiveRetraction).messageId, 'm1');
      expect(batch.continuation, 'NEXT');
      expect(batch.pullDelay, const Duration(seconds: 3));
      expect(batch.over, isFalse);
    });

    test('a missing liveChatContinuation ends the chat with its notice', () {
      final body = jsonDecode(
        jsonEncode({
          'messageResponses': [
            {
              'messageRenderer': {
                'text': {
                  'runs': [
                    {'text': 'Replay chat has ended'},
                  ],
                },
              },
            },
          ],
        }),
      );
      final batch = YoutubeDanmakuCodec.parse(body);
      expect(batch.over, isTrue);
      expect(batch.notice, 'Replay chat has ended');
    });

    test('a super chat takes its price from the amount text and its pin from the colour tier', () {
      LiveMessage parseSuperChat(int header) {
        final body = jsonDecode(
          jsonEncode({
            'continuationContents': {
              'liveChatContinuation': {
                'actions': [
                  {
                    'addChatItemAction': {
                      'item': {
                        'liveChatPaidMessageRenderer': {
                          'purchaseAmountText': {'simpleText': '₩10,000'},
                          'message': {'simpleText': 'hi'},
                          'authorName': {'simpleText': 'Bob'},
                          'id': 'sc-1',
                          'timestampUsec': '1727380001000000',
                          'headerBackgroundColor': header,
                        },
                      },
                    },
                  },
                ],
                'continuations': [
                  {
                    'timedContinuationData': {'continuation': 'NEXT', 'timeoutMs': 3000},
                  },
                ],
              },
            },
          }),
        );
        return YoutubeDanmakuCodec.parse(body).messages.single;
      }

      // 0xFF00BFA5 is the green tier: pinned 2 minutes; the won amount groups to 10000.
      final green = parseSuperChat(0xFF00BFA5).payload! as LiveSuperChatMessage;
      expect(green.price.amount, 10000);
      expect(green.price.displayText, '₩10,000');
      expect(green.endTime!.difference(green.startTime!), const Duration(minutes: 2));
      expect(green.display.backgroundColor, '#00bfa5');

      // An unknown colour is not a named tier: the shortest display, no fill-in.
      final plain = parseSuperChat(0xFFFFFFFF).payload! as LiveSuperChatMessage;
      expect(plain.endTime!.difference(plain.startTime!), const Duration(minutes: 1));
    });
  });

  test('continuation poll interval clamps to 1..5 seconds', () {
    expect(YoutubeDanmakuCodec.pullDelay(200), const Duration(seconds: 1));
    expect(YoutubeDanmakuCodec.pullDelay(3000), const Duration(seconds: 3));
    expect(YoutubeDanmakuCodec.pullDelay(30000), const Duration(seconds: 5));
    expect(YoutubeDanmakuCodec.pullDelay(0), const Duration(seconds: 5));
  });

  group('HLS master', () {
    final expire = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
    final masterUrl = 'https://manifest.googlevideo.com/hls/master.m3u8?expire=$expire';
    final master =
        '#EXTM3U\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1280x720,FRAME-RATE=30.000,CODECS="avc1.64001f,opus"\n'
        'https://manifest.googlevideo.com/hls/720p/index.m3u8?expire=$expire\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=12000000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="avc1.640034"\n'
        'https://manifest.googlevideo.com/hls/1080p/index.m3u8?expire=$expire\n';

    test('variants, qualities, a line and its lease', () {
      final variants = YoutubePlayParser.variants(master, Uri.parse(masterUrl));
      expect(variants, hasLength(2));
      expect(variants.first.height, 720);
      expect(variants.first.fps, 30);
      expect(variants.first.codec, LiveStreamCodec.avc);

      final qualities = YoutubePlayParser.qualities(variants: variants, hlsManifestUrl: masterUrl);
      expect(qualities.map((q) => q.qualityId), containsAll(['hls:720:30:avc', 'hls:1080:fps0:avc']));

      final lines = YoutubePlayParser.lines(
        variants: variants,
        videoId: _videoId,
        issuedAt: DateTime.now(),
        hlsManifestUrl: masterUrl,
        qualityId: 'hls:720:30:avc',
      );
      expect(lines.single.url, contains('720p'));
      expect(lines.single.format, LiveStreamFormat.hls);
      expect(lines.single.lease, isNotNull);
      expect(lines.single.headers['referer'], 'https://www.youtube.com/watch?v=$_videoId');
    });

    test('host allowlist rejects off-site, fragment and user-info URLs', () {
      expect(() => YoutubePlayParser.allowlisted('https://evil.example/x.m3u8'), throwsA(isA<YouTubeFailure>()));
      expect(
        () => YoutubePlayParser.allowlisted('https://manifest.googlevideo.com/a.m3u8#frag'),
        throwsA(isA<YouTubeFailure>()),
      );
      expect(
        () => YoutubePlayParser.allowlisted('https://u@manifest.googlevideo.com/a.m3u8'),
        throwsA(isA<YouTubeFailure>()),
      );
    });
  });

  group('search', () {
    test('first page carries the literal Live filter', () {
      final body = YoutubeEndpoints.searchPage1Body('kw');
      expect(body['params'], 'EgJAAQ%3D%3D');
      expect(body['query'], 'kw');
      expect(((body['context']! as Map)['client']! as Map)['clientName'], 'WEB');
    });

    test('cards and the continuation token are read from a page', () {
      final node = jsonDecode(
        jsonEncode({
          'contents': {
            'richItemRenderer': {
              'content': {
                'videoRenderer': {
                  'videoId': _videoId,
                  'title': {'simpleText': 'Live One'},
                  'ownerText': {
                    'runs': [
                      {
                        'text': 'Chan',
                        'navigationEndpoint': {
                          'browseEndpoint': {'browseId': _channelId},
                        },
                      },
                    ],
                  },
                  'badges': [
                    {
                      'metadataBadgeRenderer': {'label': 'LIVE'},
                    },
                  ],
                  'viewCountText': {'simpleText': '5 watching'},
                  'thumbnail': {
                    'thumbnails': [
                      {'url': '//i.ytimg.com/1.jpg'},
                    ],
                  },
                },
              },
            },
          },
          'continuationItemRenderer': {
            'continuationEndpoint': {
              'continuationCommand': {'token': 'NEXT1'},
            },
          },
        }),
      );
      final rooms = YoutubeRoomParser.rooms(node);
      expect(rooms.single.roomId, _channelId);
      expect(rooms.single.content.title, 'Live One');
      expect(rooms.single.broadcast.isLiveNow, isTrue);
      expect(rooms.single.audience.onlineViewers, 5);
      expect(YoutubeRoomParser.nextContinuation(node), 'NEXT1');
    });
  });

  group('link resolution', () {
    test('video and channel forms are recognised without a request', () {
      expect(YoutubeLinkResolver.videoIdOf('www.youtube.com', ['watch'], const {'v': _videoId}), _videoId);
      expect(YoutubeLinkResolver.videoIdOf('youtu.be', [_videoId], const {}), _videoId);
      expect(YoutubeLinkResolver.videoIdOf('m.youtube.com', ['live', _videoId], const {}), _videoId);
      expect(YoutubeLinkResolver.videoIdOf('www.youtube.com', ['embed', _videoId], const {}), _videoId);
      expect(YoutubeLinkResolver.channelOf(['channel', _channelId], const {})!.browseId, _channelId);
      expect(YoutubeLinkResolver.isYoutubeHost('music.youtube.com'), isTrue);
      expect(YoutubeLinkResolver.isYoutubeHost('example.com'), isFalse);
    });

    test('resolve canonicalises watch, youtu.be and channel links', () async {
      final resolver = YoutubeLinkResolver(site: _site('{}'));
      expect(
        _right(await resolver.resolve(Uri.parse('https://www.youtube.com/watch?v=$_videoId'))).toString(),
        'https://www.youtube.com/watch?v=$_videoId',
      );
      expect(
        _right(await resolver.resolve(Uri.parse('https://youtu.be/$_videoId'))).toString(),
        'https://www.youtube.com/watch?v=$_videoId',
      );
      expect(
        _right(await resolver.resolve(Uri.parse('https://www.youtube.com/channel/$_channelId/live'))).toString(),
        'https://www.youtube.com/channel/$_channelId/live',
      );
    });

    test('a handle channel is resolved through resolve_url', () async {
      final site = _site(
        jsonEncode({
          'endpoint': {
            'watchEndpoint': {'videoId': _videoId},
          },
        }),
      );
      final resolver = YoutubeLinkResolver(site: site);
      final resolved = _right(await resolver.resolve(Uri.parse('https://www.youtube.com/@foo/live')));
      expect(resolved.toString(), 'https://www.youtube.com/watch?v=$_videoId');
    });
  });
}
