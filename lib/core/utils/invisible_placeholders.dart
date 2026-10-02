/// 平台留下的不可见占位字符（上游 M13.16 的 `stripInvisiblePlaceholders`）。
///
/// 这个文件刻意不依赖任何东西：房间模型与弹幕消息都要用它，而模型层不该为了
/// 一个正则去拉进 UI/GetX 那一整条依赖链。
library;

/// 平台在“原本有图”的位置留下的不可见占位字符，字体画出来是个方块
/// （快手标题里的 U+FFFC 就显示成 "OBJ"）：对象替换符 U+FFFC、行间注记符
/// U+FFF9–U+FFFB、非字符 U+FFFE/U+FFFF，以及除制表与换行外的 C0/C1 控制符。
///
/// 渲染上本来就不可见、而且有意义的格式字符要保留：零宽空格 U+200B（断行机会）、
/// 连接符 U+200C/U+200D/U+2060（emoji 序列、脚本、颜文字要保持一行）、U+FEFF；
/// 替换符 U+FFFD 也保留——它是文本损坏的可见信号。
final RegExp _invisiblePlaceholders = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F￹-￼￾￿]');

/// 去掉 [text] 里的不可见占位字符；没有时原样返回。
String stripInvisiblePlaceholders(String text) =>
    _invisiblePlaceholders.hasMatch(text) ? text.replaceAll(_invisiblePlaceholders, '') : text;

/// [stripInvisiblePlaceholders] 的可空版本。
String? stripInvisiblePlaceholdersOrNull(String? text) => text == null ? null : stripInvisiblePlaceholders(text);
