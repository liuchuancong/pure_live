// The title parser, pinned: decorations go, the two artist/title shapes are
// read apart, and a title without either shape keeps its whole text with the
// uploader as the artist.
import 'package:live_vod/live_vod.dart';
import 'package:test/test.dart';

void main() {
  test('an "artist - title" title is split in that order', () {
    final query = LyricQuery.fromVideoTitle('周杰伦 - 稻香');
    expect(query.title, '稻香');
    expect(query.artist, '周杰伦');
  });

  test('brackets and tags are stripped before splitting', () {
    final query = LyricQuery.fromVideoTitle('【4K修复】周杰伦 - 稻香【MV】');
    expect(query.title, '稻香');
    expect(query.artist, '周杰伦');
  });

  test('a book-title shape is read as title《artist》', () {
    final query = LyricQuery.fromVideoTitle('稻香《周杰伦》');
    expect(query.title, '稻香');
    expect(query.artist, '周杰伦');
  });

  test('a hyphenated word is not a separator', () {
    final query = LyricQuery.fromVideoTitle('Lo-Fi 版本测试', uploader: '某UP主');
    expect(query.title, 'Lo-Fi 版本测试');
    expect(query.artist, '某UP主');
  });

  test('the uploader is the artist when the title names none', () {
    final query = LyricQuery.fromVideoTitle('稻香 纯享版', uploader: '音乐搬运工');
    expect(query.title, '稻香 纯享版');
    expect(query.artist, '音乐搬运工');
  });

  test('an all-decoration title stays usable as its cleaned text', () {
    final query = LyricQuery.fromVideoTitle('【MV】【4K】');
    expect(query.isUsable, isFalse);
  });

  test('a decorated uploader is cleaned too', () {
    final query = LyricQuery.fromVideoTitle('稻香', uploader: '【官方】周杰伦');
    expect(query.artist, '周杰伦');
  });
}
