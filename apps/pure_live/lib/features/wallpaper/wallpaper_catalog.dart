/// The compiled-in wallpaper presets: the solid palette and the gradient
/// ramp, ported from the reference's `wallpaper_presets.dart`.
///
/// The names are the iTab new-tab page's own published names and are shown
/// as written; the angles follow the CSS convention (0deg points up,
/// clockwise positive) and are converted to alignments at render time by
/// `wallpaper_style.dart`. Purely a const catalogue: the reference's network
/// sources (the random-image APIs and the git-mirror library) are out of
/// scope for this build.
library;

import 'package:flutter/painting.dart' show Color;

/// One built-in gradient preset.
final class WallpaperGradientPreset {
  /// A gradient named [name] running at the CSS angle [angle] through
  /// [stops].
  const new(this.name, this.angle, this.stops);

  /// Display name, as published by iTab.
  final String name;

  /// CSS gradient angle in degrees.
  final int angle;

  /// Colour stops: (hex colour, position in percent).
  final List<(String, double)> stops;

  /// The stop colours as ARGB ints, in order.
  List<int> get argbColors => [for (final (hex, _) in stops) _argb(hex)];

  /// The stop positions normalized to 0..1, aligned with [argbColors].
  List<double> get positions => [for (final (_, percent) in stops) percent / 100];
}

/// One built-in solid preset.
final class WallpaperSolidPreset {
  /// A flat colour named [name].
  const new(this.name, this.hex);

  /// Display name, as published by iTab.
  final String name;

  /// The hex colour, with or without the leading `#`.
  final String hex;

  /// The colour as a 32-bit ARGB value.
  int get argb => _argb(hex);

  /// The colour.
  Color get color => Color(argb);
}

int _argb(String hex) => 0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16);

/// The flat colour swatches offered above the gradients, in iTab's order.
const List<WallpaperSolidPreset> kWallpaperSolidPresets = <WallpaperSolidPreset>[
  WallpaperSolidPreset('White', '#ffffff'),
  WallpaperSolidPreset('Blue', '#3b78dc'),
  WallpaperSolidPreset('Cyan', '#00afc7'),
  WallpaperSolidPreset('Indigo', '#3b4ba8'),
  WallpaperSolidPreset('Purple', '#8d24a0'),
  WallpaperSolidPreset('Teal', '#008b7d'),
  WallpaperSolidPreset('Green', '#0f9251'),
  WallpaperSolidPreset('Lime', '#bbc934'),
  WallpaperSolidPreset('Amber', '#e2a600'),
  WallpaperSolidPreset('Red', '#c83e32'),
  WallpaperSolidPreset('Brown', '#704f42'),
  WallpaperSolidPreset('Blue grey', '#58727f'),
];

/// The whole gradient ramp, in iTab's own order.
const List<WallpaperGradientPreset> kWallpaperGradientPresets = <WallpaperGradientPreset>[
  WallpaperGradientPreset('Night Fade', 0, <(String, double)>[('#a18cd1', 0.0), ('#fbc2eb', 100.0)]),
  WallpaperGradientPreset('Lady Lips', 0, <(String, double)>[('#ff9a9e', 0.0), ('#fecfef', 99.0), ('#fecfef', 100.0)]),
  WallpaperGradientPreset('Rainy Ashville', 0, <(String, double)>[('#fbc2eb', 0.0), ('#a6c1ee', 100.0)]),
  WallpaperGradientPreset('Frozen Dreams', 0, <(String, double)>[
    ('#fdcbf1', 0.0),
    ('#fdcbf1', 1.0),
    ('#e6dee9', 100.0),
  ]),
  WallpaperGradientPreset('Winter Neva', 120, <(String, double)>[('#a1c4fd', 0.0), ('#c2e9fb', 100.0)]),
  WallpaperGradientPreset('Dusty Grass', 120, <(String, double)>[('#d4fc79', 0.0), ('#96e6a1', 100.0)]),
  WallpaperGradientPreset('Tempting Azure', 120, <(String, double)>[('#84fab0', 0.0), ('#8fd3f4', 100.0)]),
  WallpaperGradientPreset('Heavy Rain', 0, <(String, double)>[('#cfd9df', 0.0), ('#e2ebf0', 100.0)]),
  WallpaperGradientPreset('Amy Crisp', 120, <(String, double)>[('#a6c0fe', 0.0), ('#f68084', 100.0)]),
  WallpaperGradientPreset('Deep Blue', 120, <(String, double)>[('#e0c3fc', 0.0), ('#8ec5fc', 100.0)]),
  WallpaperGradientPreset('Ripe Malinka', 120, <(String, double)>[('#f093fb', 0.0), ('#f5576c', 100.0)]),
  WallpaperGradientPreset('Cloudy Knoxville', 120, <(String, double)>[('#fdfbfb', 0.0), ('#ebedee', 100.0)]),
  WallpaperGradientPreset('Malibu Beach', 0, <(String, double)>[('#4facfe', 0.0), ('#00f2fe', 100.0)]),
  WallpaperGradientPreset('New Life', 0, <(String, double)>[('#43e97b', 0.0), ('#38f9d7', 100.0)]),
  WallpaperGradientPreset('Morpheus Den', 0, <(String, double)>[('#30cfd0', 0.0), ('#330867', 100.0)]),
  WallpaperGradientPreset('Rare Wind', 0, <(String, double)>[('#a8edea', 0.0), ('#fed6e3', 100.0)]),
  WallpaperGradientPreset('Near Moon', 0, <(String, double)>[('#5ee7df', 0.0), ('#b490ca', 100.0)]),
  WallpaperGradientPreset('Wild Apple', 0, <(String, double)>[('#d299c2', 0.0), ('#fef9d7', 100.0)]),
  WallpaperGradientPreset('Saint Petersburg', 135, <(String, double)>[('#f5f7fa', 0.0), ('#c3cfe2', 100.0)]),
  WallpaperGradientPreset('Arielles Smile', 0, <(String, double)>[
    ('#16d9e3', 0.0),
    ('#30c7ec', 47.0),
    ('#46aef7', 100.0),
  ]),
  WallpaperGradientPreset('Plum Plate', 135, <(String, double)>[('#667eea', 0.0), ('#764ba2', 100.0)]),
  WallpaperGradientPreset('Everlasting Sky', 135, <(String, double)>[('#fdfcfb', 0.0), ('#e2d1c3', 100.0)]),
  WallpaperGradientPreset('Happy Fisher', 120, <(String, double)>[('#89f7fe', 0.0), ('#66a6ff', 100.0)]),
  WallpaperGradientPreset('Sharpeye Eagle', 0, <(String, double)>[('#9890e3', 0.0), ('#b1f4cf', 100.0)]),
  WallpaperGradientPreset('Ladoga Bottom', 0, <(String, double)>[('#ebc0fd', 0.0), ('#d9ded8', 100.0)]),
  WallpaperGradientPreset('Itmeo Branding', 180, <(String, double)>[('#2af598', 0.0), ('#009efd', 100.0)]),
  WallpaperGradientPreset('Zeus Miracle', 0, <(String, double)>[('#cd9cf2', 0.0), ('#f6f3ff', 100.0)]),
  WallpaperGradientPreset('Star Wine', 0, <(String, double)>[
    ('#b8cbb8', 0.0),
    ('#b8cbb8', 0.0),
    ('#b465da', 0.0),
    ('#cf6cc9', 33.0),
    ('#ee609c', 66.0),
    ('#ee609c', 100.0),
  ]),
  WallpaperGradientPreset('Blue Velvet', 0, <(String, double)>[('#6a11cb', 0.0), ('#2575fc', 100.0)]),
  WallpaperGradientPreset('Happy Acid', 0, <(String, double)>[('#37ecba', 0.0), ('#72afd3', 100.0)]),
  WallpaperGradientPreset('New York', 0, <(String, double)>[('#fff1eb', 0.0), ('#ace0f9', 100.0)]),
  WallpaperGradientPreset('Shy Rainbow', 0, <(String, double)>[('#eea2a2', 0.0), ('#bbc1bf', 19.0), ('#57c6e1', 42.0)]),
  WallpaperGradientPreset('Mixed Hopes', 0, <(String, double)>[('#c471f5', 0.0), ('#fa71cd', 100.0)]),
  WallpaperGradientPreset('Fly High', 0, <(String, double)>[('#48c6ef', 0.0), ('#6f86d6', 100.0)]),
  WallpaperGradientPreset('Snow Again', 0, <(String, double)>[('#e6e9f0', 0.0), ('#eef1f5', 100.0)]),
  WallpaperGradientPreset('February Ink', 0, <(String, double)>[('#accbee', 0.0), ('#e7f0fd', 100.0)]),
  WallpaperGradientPreset('Kind Steel', -20, <(String, double)>[('#e9defa', 0.0), ('#fbfcdb', 100.0)]),
  WallpaperGradientPreset('Soft Grass', 0, <(String, double)>[('#c1dfc4', 0.0), ('#deecdd', 100.0)]),
  WallpaperGradientPreset('Grown Early', 0, <(String, double)>[('#0ba360', 0.0), ('#3cba92', 100.0)]),
  WallpaperGradientPreset('Sharp Blues', 0, <(String, double)>[('#00c6fb', 0.0), ('#005bea', 100.0)]),
  WallpaperGradientPreset('Shady Water', 0, <(String, double)>[('#74ebd5', 0.0), ('#9face6', 100.0)]),
  WallpaperGradientPreset('Dirty Beauty', 0, <(String, double)>[('#6a85b6', 0.0), ('#bac8e0', 100.0)]),
  WallpaperGradientPreset('Great Whale', 0, <(String, double)>[('#a3bded', 0.0), ('#6991c7', 100.0)]),
  WallpaperGradientPreset('Teen Notebook', 0, <(String, double)>[('#9795f0', 0.0), ('#fbc8d4', 100.0)]),
  WallpaperGradientPreset('Polite Rumors', 0, <(String, double)>[
    ('#a7a6cb', 0.0),
    ('#8989ba', 52.0),
    ('#8989ba', 100.0),
  ]),
  WallpaperGradientPreset('Soft Cherish', 0, <(String, double)>[
    ('#dbdcd7', 0.0),
    ('#dddcd7', 24.0),
    ('#e2c9cc', 30.0),
    ('#e7627d', 46.0),
    ('#b8235a', 59.0),
    ('#801357', 71.0),
    ('#3d1635', 84.0),
    ('#1c1a27', 100.0),
  ]),
  WallpaperGradientPreset('Red Salvation', 0, <(String, double)>[('#f43b47', 0.0), ('#453a94', 100.0)]),
  WallpaperGradientPreset('Burning Spring', 0, <(String, double)>[
    ('#4fb576', 0.0),
    ('#44c489', 30.0),
    ('#28a9ae', 46.0),
    ('#28a2b7', 59.0),
    ('#4c7788', 71.0),
    ('#6c4f63', 80.0),
    ('#432c39', 100.0),
  ]),
  WallpaperGradientPreset('Night Party', 0, <(String, double)>[('#0250c5', 0.0), ('#d43f8d', 100.0)]),
  WallpaperGradientPreset('Sky Glider', 0, <(String, double)>[('#88d3ce', 0.0), ('#6e45e2', 100.0)]),
  WallpaperGradientPreset('Heaven Peach', 0, <(String, double)>[('#d9afd9', 0.0), ('#97d9e1', 100.0)]),
  WallpaperGradientPreset('Purple Division', 0, <(String, double)>[('#7028e4', 0.0), ('#e5b2ca', 100.0)]),
  WallpaperGradientPreset('Aqua Splash', 15, <(String, double)>[('#13547a', 0.0), ('#80d0c7', 100.0)]),
  WallpaperGradientPreset('Above Clouds', 0, <(String, double)>[('#BDBBBE', 0.0), ('#9D9EA3', 100.0)]),
  WallpaperGradientPreset('Spiky Naga', 0, <(String, double)>[('#505285', 0.0), ('#585e92', 12.0), ('#65689f', 25.0)]),
  WallpaperGradientPreset('Clean Mirror', 45, <(String, double)>[('#93a5cf', 0.0), ('#e4efe9', 100.0)]),
  WallpaperGradientPreset('Premium Dark', 0, <(String, double)>[('#434343', 0.0), ('#000000', 100.0)]),
  WallpaperGradientPreset('Cold Evening', 0, <(String, double)>[
    ('#0c3483', 0.0),
    ('#a2b6df', 100.0),
    ('#6b8cce', 100.0),
  ]),
  WallpaperGradientPreset('Cochiti Lake', 45, <(String, double)>[('#93a5cf', 0.0), ('#e4efe9', 100.0)]),
  WallpaperGradientPreset('Summer Games', 0, <(String, double)>[('#92fe9d', 0.0), ('#00c9ff', 100.0)]),
  WallpaperGradientPreset('Mountain Rock', 0, <(String, double)>[('#868f96', 0.0), ('#596164', 100.0)]),
  WallpaperGradientPreset('Jungle Day', 45, <(String, double)>[('#8baaaa', 0.0), ('#ae8b9c', 100.0)]),
  WallpaperGradientPreset('October Silence', -20, <(String, double)>[('#b721ff', 0.0), ('#21d4fd', 100.0)]),
  WallpaperGradientPreset('Faraway River', -20, <(String, double)>[('#6e45e2', 0.0), ('#88d3ce', 100.0)]),
  WallpaperGradientPreset('Alchemist Lab', -20, <(String, double)>[('#d558c8', 0.0), ('#24d292', 100.0)]),
  WallpaperGradientPreset('Over Sun', 60, <(String, double)>[('#abecd6', 0.0), ('#fbed96', 100.0)]),
  WallpaperGradientPreset('Premium White', 0, <(String, double)>[
    ('#d5d4d0', 0.0),
    ('#d5d4d0', 1.0),
    ('#eeeeec', 31.0),
  ]),
  WallpaperGradientPreset('Mars Party', 0, <(String, double)>[('#5f72bd', 0.0), ('#9b23ea', 100.0)]),
  WallpaperGradientPreset('Eternal Constance', 0, <(String, double)>[('#09203f', 0.0), ('#537895', 100.0)]),
  WallpaperGradientPreset('Smiling Rain', -20, <(String, double)>[('#dcb0ed', 0.0), ('#99c99c', 100.0)]),
  WallpaperGradientPreset('Cloudy Apple', 0, <(String, double)>[
    ('#f3e7e9', 0.0),
    ('#e3eeff', 99.0),
    ('#e3eeff', 100.0),
  ]),
  WallpaperGradientPreset('Big Mango', 0, <(String, double)>[('#c71d6f', 0.0), ('#d09693', 100.0)]),
  WallpaperGradientPreset('Healthy Water', 60, <(String, double)>[('#96deda', 0.0), ('#50c9c3', 100.0)]),
  WallpaperGradientPreset('Amour Amour', 0, <(String, double)>[('#f77062', 0.0), ('#fe5196', 100.0)]),
  WallpaperGradientPreset('Risky Concrete', 0, <(String, double)>[
    ('#c4c5c7', 0.0),
    ('#dcdddf', 52.0),
    ('#ebebeb', 100.0),
  ]),
  WallpaperGradientPreset('Strong Stick', 0, <(String, double)>[('#a8caba', 0.0), ('#5d4157', 100.0)]),
  WallpaperGradientPreset('Vicious Stance', 60, <(String, double)>[('#29323c', 0.0), ('#485563', 100.0)]),
  WallpaperGradientPreset('Palo Alto', -60, <(String, double)>[('#16a085', 0.0), ('#f4d03f', 100.0)]),
  WallpaperGradientPreset('Midnight Bloom', -20, <(String, double)>[('#2b5876', 0.0), ('#4e4376', 100.0)]),
  WallpaperGradientPreset('Crystalline', -20, <(String, double)>[('#00cdac', 0.0), ('#8ddad5', 100.0)]),
  WallpaperGradientPreset('Raccoon Back', -180, <(String, double)>[('#BCC5CE', 0.0), ('#929EAD', 98.0)]),
  WallpaperGradientPreset('Party Bliss', 0, <(String, double)>[('#4481eb', 0.0), ('#04befe', 100.0)]),
  WallpaperGradientPreset('Confident Cloud', 0, <(String, double)>[
    ('#dad4ec', 0.0),
    ('#dad4ec', 1.0),
    ('#f3e7e9', 100.0),
  ]),
  WallpaperGradientPreset('River City', 0, <(String, double)>[('#4481eb', 0.0), ('#04befe', 100.0)]),
  WallpaperGradientPreset('Frozen Berry', 0, <(String, double)>[('#e8198b', 0.0), ('#c7eafd', 100.0)]),
  WallpaperGradientPreset('Elegance', 0, <(String, double)>[('#EADFDF', 59.0), ('#ECE2DF', 100.0)]),
  WallpaperGradientPreset('Flying Lemon', 60, <(String, double)>[('#64b3f4', 0.0), ('#c2e59c', 100.0)]),
  WallpaperGradientPreset('Hidden Jaguar', 0, <(String, double)>[('#0fd850', 0.0), ('#f9f047', 100.0)]),
  WallpaperGradientPreset('Above The Sky', 0, <(String, double)>[
    ('#d3d3d3', 0.0),
    ('#d3d3d3', 1.0),
    ('#e0e0e0', 26.0),
  ]),
  WallpaperGradientPreset('Dense Water', 0, <(String, double)>[
    ('#3ab5b0', 0.0),
    ('#3d99be', 31.0),
    ('#56317a', 100.0),
  ]),
  WallpaperGradientPreset('Seashore', 0, <(String, double)>[('#209cff', 0.0), ('#68e0cf', 100.0)]),
  WallpaperGradientPreset('Marble Wall', 0, <(String, double)>[('#bdc2e8', 0.0), ('#bdc2e8', 1.0), ('#e6dee9', 100.0)]),
  WallpaperGradientPreset('Night Sky', 0, <(String, double)>[('#1e3c72', 0.0), ('#1e3c72', 1.0), ('#2a5298', 100.0)]),
  WallpaperGradientPreset('Young Grass', 0, <(String, double)>[('#9be15d', 0.0), ('#00e3ae', 100.0)]),
  WallpaperGradientPreset('Plum Bath', 0, <(String, double)>[('#cc208e', 0.0), ('#6713d2', 100.0)]),
  WallpaperGradientPreset('Happy Unicorn', 0, <(String, double)>[('#b3ffab', 0.0), ('#12fff7', 100.0)]),
  WallpaperGradientPreset('Full Metal', 0, <(String, double)>[('#D5DEE7', 0.0), ('#E8EBF2', 50.0), ('#E2E7ED', 100.0)]),
  WallpaperGradientPreset('Solid Stone', 0, <(String, double)>[('#243949', 0.0), ('#517fa4', 100.0)]),
  WallpaperGradientPreset('Glass Water', 0, <(String, double)>[('#dfe9f3', 0.0), ('#ffffff', 100.0)]),
  WallpaperGradientPreset('North Miracle', 0, <(String, double)>[('#00dbde', 0.0), ('#fc00ff', 100.0)]),
  WallpaperGradientPreset('Millennium Pine', 0, <(String, double)>[('#50cc7f', 0.0), ('#f5d100', 100.0)]),
  WallpaperGradientPreset('High Flight', 0, <(String, double)>[('#0acffe', 0.0), ('#495aff', 100.0)]),
  WallpaperGradientPreset('Mole Hall', -20, <(String, double)>[('#616161', 0.0), ('#9bc5c3', 100.0)]),
  WallpaperGradientPreset('Space Shift', 60, <(String, double)>[
    ('#3d3393', 0.0),
    ('#2b76b9', 37.0),
    ('#2cacd1', 65.0),
    ('#35eb93', 100.0),
  ]),
  WallpaperGradientPreset('Forest Inei', 0, <(String, double)>[('#df89b5', 0.0), ('#bfd9fe', 100.0)]),
  WallpaperGradientPreset('Royal Garden', 0, <(String, double)>[('#ed6ea0', 0.0), ('#ec8c69', 100.0)]),
  WallpaperGradientPreset('Rich Metal', 0, <(String, double)>[('#d7d2cc', 0.0), ('#304352', 100.0)]),
  WallpaperGradientPreset('Smart Indigo', 0, <(String, double)>[('#b224ef', 0.0), ('#7579ff', 100.0)]),
  WallpaperGradientPreset('Sand Strike', 0, <(String, double)>[('#c1c161', 0.0), ('#c1c161', 0.0), ('#d4d4b1', 100.0)]),
  WallpaperGradientPreset('Norse Beauty', 0, <(String, double)>[('#ec77ab', 0.0), ('#7873f5', 100.0)]),
  WallpaperGradientPreset('Aqua Guidance', 0, <(String, double)>[('#007adf', 0.0), ('#00ecbc', 100.0)]),
  WallpaperGradientPreset('Sun Veggie', -225, <(String, double)>[('#20E2D7', 0.0), ('#F9FEA5', 100.0)]),
  WallpaperGradientPreset('Sea Lord', -225, <(String, double)>[
    ('#2CD8D5', 0.0),
    ('#C5C1FF', 56.0),
    ('#FFBAC3', 100.0),
  ]),
  WallpaperGradientPreset('Black Sea', -225, <(String, double)>[
    ('#2CD8D5', 0.0),
    ('#6B8DD6', 48.0),
    ('#8E37D7', 100.0),
  ]),
  WallpaperGradientPreset('Grass Shampoo', -225, <(String, double)>[
    ('#DFFFCD', 0.0),
    ('#90F9C4', 48.0),
    ('#39F3BB', 100.0),
  ]),
  WallpaperGradientPreset('Landing Aircraft', -225, <(String, double)>[
    ('#5D9FFF', 0.0),
    ('#B8DCFF', 48.0),
    ('#6BBBFF', 100.0),
  ]),
  WallpaperGradientPreset('Witch Dance', -225, <(String, double)>[('#A8BFFF', 0.0), ('#884D80', 100.0)]),
  WallpaperGradientPreset('Sleepless Night', -225, <(String, double)>[
    ('#5271C4', 0.0),
    ('#B19FFF', 48.0),
    ('#ECA1FE', 100.0),
  ]),
  WallpaperGradientPreset('Crystal River', -225, <(String, double)>[
    ('#22E1FF', 0.0),
    ('#1D8FE1', 48.0),
    ('#625EB1', 100.0),
  ]),
  WallpaperGradientPreset('Soft Lipstick', -225, <(String, double)>[('#B6CEE8', 0.0), ('#F578DC', 100.0)]),
  WallpaperGradientPreset('Salt Mountain', -225, <(String, double)>[('#FFFEFF', 0.0), ('#D7FFFE', 100.0)]),
  WallpaperGradientPreset('Perfect White', -225, <(String, double)>[('#E3FDF5', 0.0), ('#FFE6FA', 100.0)]),
  WallpaperGradientPreset('Fresh Oasis', -225, <(String, double)>[('#7DE2FC', 0.0), ('#B9B6E5', 100.0)]),
  WallpaperGradientPreset('Strict November', -225, <(String, double)>[('#CBBACC', 0.0), ('#2580B3', 100.0)]),
  WallpaperGradientPreset('Morning Salad', -225, <(String, double)>[('#B7F8DB', 0.0), ('#50A7C2', 100.0)]),
  WallpaperGradientPreset('Deep Relief', -225, <(String, double)>[
    ('#7085B6', 0.0),
    ('#87A7D9', 50.0),
    ('#DEF3F8', 100.0),
  ]),
  WallpaperGradientPreset('Sea Strike', -225, <(String, double)>[
    ('#77FFD2', 0.0),
    ('#6297DB', 48.0),
    ('#1EECFF', 100.0),
  ]),
  WallpaperGradientPreset('Night Call', -225, <(String, double)>[
    ('#AC32E4', 0.0),
    ('#7918F2', 48.0),
    ('#4801FF', 100.0),
  ]),
  WallpaperGradientPreset('Supreme Sky', -225, <(String, double)>[
    ('#D4FFEC', 0.0),
    ('#57F2CC', 48.0),
    ('#4596FB', 100.0),
  ]),
  WallpaperGradientPreset('Light Blue', -225, <(String, double)>[
    ('#9EFBD3', 0.0),
    ('#57E9F2', 48.0),
    ('#45D4FB', 100.0),
  ]),
  WallpaperGradientPreset('Mind Crawl', -225, <(String, double)>[
    ('#473B7B', 0.0),
    ('#3584A7', 51.0),
    ('#30D2BE', 100.0),
  ]),
  WallpaperGradientPreset('Lily Meadow', -225, <(String, double)>[
    ('#65379B', 0.0),
    ('#886AEA', 53.0),
    ('#6457C6', 100.0),
  ]),
  WallpaperGradientPreset('Sugar Lollipop', -225, <(String, double)>[
    ('#A445B2', 0.0),
    ('#D41872', 52.0),
    ('#FF0066', 100.0),
  ]),
  WallpaperGradientPreset('Sweet Dessert', -225, <(String, double)>[
    ('#7742B2', 0.0),
    ('#F180FF', 52.0),
    ('#FD8BD9', 100.0),
  ]),
  WallpaperGradientPreset('Magic Ray', -225, <(String, double)>[
    ('#FF3CAC', 0.0),
    ('#562B7C', 52.0),
    ('#2B86C5', 100.0),
  ]),
  WallpaperGradientPreset('Teen Party', -225, <(String, double)>[
    ('#FF057C', 0.0),
    ('#8D0B93', 50.0),
    ('#321575', 100.0),
  ]),
  WallpaperGradientPreset('Frozen Heat', -225, <(String, double)>[
    ('#FF057C', 0.0),
    ('#7C64D5', 48.0),
    ('#4CC3FF', 100.0),
  ]),
  WallpaperGradientPreset('Gagarin View', -225, <(String, double)>[
    ('#69EACB', 0.0),
    ('#EACCF8', 48.0),
    ('#6654F1', 100.0),
  ]),
  WallpaperGradientPreset('Perfect Blue', -225, <(String, double)>[
    ('#3D4E81', 0.0),
    ('#5753C9', 48.0),
    ('#6E7FF3', 100.0),
  ]),
];
