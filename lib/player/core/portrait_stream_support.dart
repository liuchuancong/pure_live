enum PortraitLayoutMode { balanced, immersive, compatibility }

enum PortraitDanmakuMode { followGlobal, upperQuarter, reduced, hidden }

// 自适应       → 自动根据安全区域计算
// 自定义高度   → 高度完全由用户指定
// 铺满         → 忽略刘海，直接铺满
enum PortraitVideoHeightMode { adaptive, custom, full }
