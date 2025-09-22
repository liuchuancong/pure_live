import 'package:flutter/material.dart';

class SlideTansWidget extends StatefulWidget {
  const SlideTansWidget({super.key, required this.child});

  final Widget child;

  @override
  SlideState createState() => SlideState();
}

class SlideState extends State<SlideTansWidget> with TickerProviderStateMixin {
  late AnimationController controller;

  late Animation<Offset> animation;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(duration: const Duration(milliseconds: 500), lowerBound: 0.5, vsync: this);

    //初始化
    //用来控制动画的开始与结束以及设置动画的监听
    //vsync参数，存在vsync时会防止屏幕外动画（动画的UI不在当前屏幕时）消耗不必要的资源
    //duration 动画的时长，这里设置的 seconds: 2 为2秒，当然也可以设置毫秒 milliseconds：2000.
    //动画开始、结束、向前移动或向后移动时会调用StatusListener
    // controller.addStatusListener((status) {
    //   if (status == AnimationStatus.completed) {
    //     //AnimationStatus.completed 动画在结束时停止的状态
    //     //ontroller.reverse();
    //   } else if (status == AnimationStatus.dismissed) {
    //     //AnimationStatus.dismissed 表示动画在开始时就停止的状态
    //     //controller.forward();
    //   }
    // });
    //begin: Offset.zero, end: Offset(1, 0) 以左下角为参考点，相对于左下角坐标 x轴方向向右 平移执行动画的view 的1倍 宽度，y轴方向不动，也就是水平向右平移
    //begin: Offset.zero, end: Offset(1, 1) 以左下角为参考点，相对于左下角坐标 x轴方向向右 平移执行动画的view 的1倍 宽度，y轴方向 向下 平衡执行动画view 的1倍的高度，也就是向右下角平移了
    // animation = Tween(begin:const Offset(-1.0, 0.0), end: Offset.zero).animate(controller);
    animation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    ));

    //开始执行动画
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: animation,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
