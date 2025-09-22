import 'package:pure_live/common/index.dart';

class HomeMobileView extends StatelessWidget {
  final Widget body;
  final int index;
  final void Function(int) onDestinationSelected;
  final void Function()? onFavoriteDoubleTap;
  const HomeMobileView({
    super.key,
    required this.body,
    required this.index,
    required this.onDestinationSelected,
    required this.onFavoriteDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(
            icon: GestureDetector(
              onDoubleTap: onFavoriteDoubleTap,
              child: const Icon(Icons.favorite_rounded),
            ),
            label: S.current.favorites_title,
          ),
          NavigationDestination(
            icon: const Icon(CustomIcons.popular),
            label: S.current.popular_title,
          ),
          NavigationDestination(
            icon: const Icon(Icons.area_chart_rounded),
            label: S.current.areas_title,
          ),
        ],
        selectedIndex: index,
        onDestinationSelected: onDestinationSelected,
      ),
      body: body,
    );
  }
}
