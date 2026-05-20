import 'package:pure_live/common/index.dart';

class SearchButton extends StatelessWidget {
  const SearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: () => Get.toNamed(RoutePath.kSearch), icon: const Icon(CustomIcons.search));
  }
}

class LinkButton extends StatelessWidget {
  const LinkButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: () => Get.toNamed(RoutePath.kToolbox), icon: const Icon(Icons.link));
  }
}
