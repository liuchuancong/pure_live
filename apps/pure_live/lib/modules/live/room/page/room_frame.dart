/// The page's own bounds for a stream's picture frame.
///
/// The stream's reported geometry is the only source of the frame now (the
/// manual per-room orientation is gone); these bounds keep an absurd report
/// from taking the whole stage or collapsing into a sliver.
library;

/// The widest frame the page draws.
const double kRoomFrameRatioMax = 2.4;

/// The narrowest frame the page draws (a tall portrait source).
const double kRoomFrameRatioMin = 0.5;
