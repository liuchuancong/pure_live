part of 'player_surface.dart';

/// The room's own cover, blurred, behind a picture that is not there.
///
/// It is the same image the feed and the follow list show, so a viewer who
/// opened this room recognises it; the blur keeps the state's text legible
/// without a second dark card on top of it.
final class _RoomCoverBackdrop extends StatelessWidget {
  const _RoomCoverBackdrop({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final cover = room.content.coverUrl.trim();
    if (cover.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: kLiveGlassCoverFrostSigma, sigmaY: kLiveGlassCoverFrostSigma),
        child: Image(
          image: cachedImage(cover, policy: ImageCachePolicies.liveRoomCover),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The art a portrait frame sits over: the room's cover, else the streamer's
/// avatar (the reference's chain after its one platform's blurred frame, which
/// no site here sends). Empty when the room has neither.
String _ambientArtOf(LiveRoom? room) {
  if (room == null) return '';
  final cover = room.content.coverUrl.trim();
  if (cover.isNotEmpty) return cover;
  return (room.anchor?.avatarUrl ?? '').trim();
}

/// The largest box of [ratio] (width over height) inside [box]: where a frame
/// fitted whole lands.
Size _containedSize(double ratio, Size box) {
  final byHeight = box.height * ratio;
  return byHeight <= box.width ? Size(byHeight, box.height) : Size(box.width, box.width / ratio);
}

/// The picture, over the room's own art when [art] is given (the reference's
/// ambient presentation of a portrait stream).
///
/// The engine paints its own black around a fitted frame, so art stacked
/// behind a view the size of the stage would never be seen. The view is sized
/// to the frame's own shape instead — the engine then has no bars left to
/// paint — and the art takes the stage around it. Without art, or before the
/// engine reports a shape, the view keeps the stage's full size, so the
/// viewer's fit decides how the frame meets it exactly as before.
///
/// The tree keeps one shape whichever of the two it draws: a view that moved
/// in and out of a wrapper would rebuild the engine's surface every time the
/// frame's shape arrived or changed.
final class _AmbientPicture extends StatelessWidget {
  const _AmbientPicture({required this.player, required this.art, required this.child});

  /// The player whose frame's shape the view follows.
  final PlayerHandle player;

  /// The art behind the frame; empty for none.
  final String art;

  /// The view itself.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final geometry = player.geometryController;
    // The stream only says when to look again; the shape is read from the
    // controller itself, so a player handed over mid-subscription is never
    // drawn with the previous player's shape.
    return StreamBuilder<GeometryState>(
      stream: geometry.state,
      builder: (context, _) {
        final state = geometry.current;
        final ratio = state.hasVideo ? state.aspectRatio : 0.0;
        final framed = art.isNotEmpty && ratio > 0 && ratio.isFinite;
        return Stack(
          fit: StackFit.expand,
          children: [
            _AmbientBackdrop(art: framed ? art : ''),
            LayoutBuilder(
              builder: (context, constraints) {
                final box = constraints.biggest;
                final size = framed ? _containedSize(ratio, box) : box;
                return Center(
                  child: SizedBox(width: size.width, height: size.height, child: child),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// The room's art behind a portrait frame (the reference's `AmbientBackdrop`).
///
/// The image is decoded a couple of dozen pixels wide and drawn across the
/// stage, which blurs it once, at decode time: a blur filter under a live
/// picture would run again on every frame the picture paints. It is blown up a
/// little past the stage so the soft image never shows an edge, under a light
/// veil that keeps it the stage and the frame the thing on it.
final class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop({required this.art});

  /// The image's address; empty leaves the stage its own black.
  final String art;

  /// The width the art is decoded at, in physical pixels (the reference's 24):
  /// small enough that drawn large it reads as a blur.
  static const int _decodeWidth = 24;

  @override
  Widget build(BuildContext context) {
    if (art.isEmpty) return const SizedBox.shrink();
    // Clipped to the stage: the blown-up image would otherwise paint over the
    // chat column or the room card beside it.
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: 1.14,
              child: Image(
                image: cachedImage(art, policy: ImageCachePolicies.albumCover, width: _decodeWidth),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            ),
            const ColoredBox(color: OnVideoColors.veil),
          ],
        ),
      ),
    );
  }
}

/// What a vertical drag on the picture changes, decided where it began.
enum _PictureDrag {
  /// The volume, or on the left half the screen's brightness.
  adjust,

  /// The portrait full screen's middle third: the next or the previous room.
  switchRoom,

  /// The portrait full screen's lowest band: back to the page's own layout.
  restore,
}

extension _PlayerSurfaceStageParts on _PlayerSurfaceState {
  /// The TV room's key scope.

  /// The TV room's key scope: the one stop that holds the keyboard when no
  /// control does, so the remote's Up and Down switch rooms instead of
  /// dying on the picture. The pointer builds pass through.
  Widget _tvScope(Widget child) {
    if (!widget.keepControls) return child;
    return Focus(focusNode: _scopeFocus, autofocus: true, onKeyEvent: _onScopeKey, child: child);
  }
}

/// The veil over a picture state's backdrop.
///
/// `cover` normally means "this state has the room's picture to show", so the
/// veil is lighter when the cover is actually drawn — otherwise the image would
/// be there only to be hidden. Every other level is the same dark the state has
/// always used.
Color _veilOf(RoomPictureDim dim, {required bool withCover}) => switch (dim) {
  RoomPictureDim.none => OnVideoColors.clear,
  RoomPictureDim.light => OnVideoColors.dimLight,
  RoomPictureDim.heavy => OnVideoColors.scrim,
  RoomPictureDim.cover => withCover ? OnVideoColors.paneGlass : OnVideoColors.coverDimHeavy,
};
