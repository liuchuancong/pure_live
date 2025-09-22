import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pure_live/common/index.dart';

class DonatePage extends StatelessWidget {
  const DonatePage({super.key});

  final widgets = const [WechatItem()];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraint) {
      final width = constraint.maxWidth;
      final crossAxisCount = width > 640 ? 2 : 1;
      return Scaffold(
        appBar: AppBar(title: Text(S.current.help_and_support)),
        body: MasonryGridView.count(
          physics: const BouncingScrollPhysics(),
          crossAxisCount: crossAxisCount,
          itemCount: 1,
          itemBuilder: (BuildContext context, int index) => widgets[index],
        ),
      );
    });
  }
}

class WechatItem extends StatelessWidget {
  const WechatItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            S.current.thank_title,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            S.current.thank_info,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            "${S.current.qq_group}：920447827",
          ),
        ),
      ],
    );
  }
}
