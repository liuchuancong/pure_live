import 'package:pure_live/common/index.dart';

class Iterum extends StatefulWidget {
  final Widget child;

  const Iterum({super.key, required this.child});

  @override
  // ignore: library_private_types_in_public_api
  _IterumState createState() => _IterumState();

  static void revive(BuildContext context) {
    context.findAncestorStateOfType<_IterumState>()!.revive();
  }
}

class _IterumState extends State<Iterum> {
  Key _key = UniqueKey();
  void revive() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
