import 'package:flutter/material.dart';
import 'package:srss/model.dart';

class RSSPage extends StatefulWidget {
  static String routeName = 'rsses';

  const RSSPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _RSSPageState();
}

class _RSSPageState extends State<RSSPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RSS 编辑'),
      ),
      body: ListView(
          children: urls
              .map((e) => Dismissible(
                  key: ValueKey(e),
                  onDismissed: (d) async {
                    await removeRSS(e);
                    setState(() {});
                  },
                  child: ListTile(
                    title: Text(e),
                    subtitle:
                        errors[e] != null ? Text(errors[e]!) : const Text(''),
                  )))
              .toList()),
    );
  }
}
