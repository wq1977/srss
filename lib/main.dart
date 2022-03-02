import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:prompt_dialog/prompt_dialog.dart';
import 'package:srss/const.dart';
import 'package:srss/model.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  init().then(
    (value) => {runApp(const MyApp())},
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: '一个简单的RSS阅读器'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<RssItem> items = [];
  Map<String, PostState> runtimeState = {};
  bool loading = false;
  String contentBase64 = '';
  addAnRSS() async {
    String? rss = await prompt(context, title: const Text('输入RSS源url'));
    if (rss != null) {
      await refreshRSS(rss);
    }
  }

  mergeItems(RssFeed feed) {
    for (var item in feed.items!) {
      String fullLink = item.link!.startsWith('http')
          ? item.link!
          : '${feed.link}${item.link}';
      if (runtimeState[fullLink] == null) {
        items.add(RssItem(
            title: item.title,
            description: item.description,
            link: fullLink,
            pubDate: item.pubDate));
        if (states[fullLink] == null) {
          runtimeState[fullLink] = PostState.psNew;
          setItemState(fullLink, PostState.psNew);
        } else {
          runtimeState[fullLink] = PostState.values[states[fullLink]!];
        }
      }
    }
    items.sort((a, b) =>
        b.pubDate!.millisecondsSinceEpoch - a.pubDate!.millisecondsSinceEpoch);
  }

  static const String htmlHeader = '''
<html>
<header>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
$css
</style>
</header>
<body>
''';
  static const String htmlEnd = '''
</body>
</html>
''';
  updateHTMLContent() async {
    contentBase64 = base64Encode(const Utf8Encoder().convert(htmlHeader +
        items
            .map((item) => '''<div onclick="router.postMessage('${item.link}')">
                <h1>${item.title}</h1>
                <div>${item.description!.contains('<p>') ? item.description : '<p>${item.description}</p>'}</div>
              </div>''')
            .join('') +
        htmlEnd));
    var controller = await _controller.future;
    controller.loadUrl('data:text/html;base64,$contentBase64');
  }

  refreshRSS(String url) async {
    url = url.trim();
    loading = true;
    if (mounted) {
      setState(() {});
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        addRSS(url);
        var rssFeed = RssFeed.parse(utf8.decode(response.bodyBytes));
        if (rssFeed.items != null) {
          mergeItems(rssFeed);
          updateHTMLContent();
          if (mounted) {
            setState(() {});
          }
        }
      } else {
        throw Exception('Failed to load album');
      }
    } catch (ex) {
      // ignore: avoid_print
      print(ex);
    }
    loading = false;
    if (mounted) {
      setState(() {});
    }
  }

  loadRss() {
    for (var url in urls) {
      refreshRSS(url);
    }
  }

  @override
  void initState() {
    loadRss();
    super.initState();
  }

  final Completer<WebViewController> _controller =
      Completer<WebViewController>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ...loading
              ? [
                  const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  )
                ]
              : [],
          IconButton(onPressed: addAnRSS, icon: const Icon(Icons.add_card))
        ],
      ),
      body: WebView(
        initialUrl: 'about:blank',
        onWebViewCreated: (WebViewController webViewController) {
          _controller.complete(webViewController);
        },
        javascriptMode: JavascriptMode.unrestricted,
        javascriptChannels: {
          JavascriptChannel(
              name: 'router',
              onMessageReceived: (JavascriptMessage url) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Second Route'),
                      ),
                      body: WebView(
                        initialUrl: url.message,
                        javascriptMode: JavascriptMode.unrestricted,
                      ),
                    ),
                  ),
                );
              })
        },
      ),
    );
  }
}
