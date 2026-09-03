import 'package:pure_live/common/index.dart';

class VideoLoading extends StatelessWidget {
  const VideoLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          ColoredBox(color: Colors.black),
          AppStatusView(
            type: AppStatusType.loading,
            title: '',
            subtitle: '',
            iconColor: Colors.white,
            isMini: true,
          ),
        ],
      ),
    );
  }
}
