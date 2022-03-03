import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:prompt_dialog/prompt_dialog.dart';
import 'package:srss/const.dart';
import 'package:srss/model.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
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
  List<PostItem> items = [];
  Map<String, PostState> runtimeState = {};
  List<String> loading = [];
  String contentBase64 = '';
  addAnRSS() async {
    String? rss = await prompt(context, title: const Text('输入RSS源url'));
    if (rss != null) {
      await refreshRSS(rss);
    }
  }

  appendItem(PostItem item) {
    String key = '${item.pubDate.millisecondsSinceEpoch}';
    if (runtimeState[key] == null &&
        states[key] != PostState.psReaded.index &&
        states[key] != PostState.psFavorite.index) {
      items.add(item);
      if (states[key] == null) {
        runtimeState[key] = PostState.psNew;
        setItemState(item.pubDate, PostState.psNew);
      } else {
        runtimeState[key] = PostState.values[states[key]!];
      }
    }
    // items.sort((a, b) =>
    //     b.pubDate.millisecondsSinceEpoch - a.pubDate.millisecondsSinceEpoch);
  }

  static const String htmlHeader = '''
<html>
<header>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
$css
</style>
<script>
window.addEventListener('scroll', function() {
  if (window.scrollendWatchTimer) {
    clearTimeout(window.scrollendWatchTimer)
  }
  window.scrollendWatchTimer = setTimeout(()=>{
    window.scrollendWatchTimer=null
    const nodes = document.querySelectorAll('.srss_post_item')
    for (var i=0;i<nodes.length;i++) {
      const node = nodes[i]
      const key = node.getAttribute('data-key')
      const rect = node.getBoundingClientRect()
      if (rect.bottom < 0) {
        hidden.postMessage(key)
        break //only hidden one item once
      }
    }
  }, 1000)
});
</script>
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
            .map((item) =>
                '''<div class="srss_post_item" data-key="${item.pubDate.millisecondsSinceEpoch}" onclick="router.postMessage('${item.link}')">
                <h1>${item.title}</h1>
                <div>${item.rssTitle}</div>
                <div>${item.description.contains('<p>') ? item.description : '<p>${item.description}</p>'}</div>
              </div>''')
            .join('') +
        htmlEnd));
    var controller = await _controller.future;
    controller.loadUrl('data:text/html;base64,$contentBase64');
  }

  refreshRSS(String url) async {
    url = url.trim();
    loading.add(url);
    if (mounted) {
      setState(() {});
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        addRSS(url);
        String xml = utf8.decode(response.bodyBytes);
        try {
          var rssFeed = RssFeed.parse(xml);
          if (rssFeed.items != null) {
            for (var e in rssFeed.items!) {
              var postitem = PostItem(
                  link: e.link!.startsWith('http')
                      ? e.link!
                      : '${rssFeed.link}${e.link}',
                  title: e.title ?? '',
                  rssTitle: rssFeed.title!,
                  description: e.description ?? '',
                  pubDate: e.pubDate!);
              appendItem(postitem);
            }
            updateHTMLContent();
            if (mounted) {
              setState(() {});
            }
          }
        } catch (ex) {
          var atomFeed = AtomFeed.parse(xml);
          if (atomFeed.items != null) {
            for (var e in atomFeed.items!) {
              var postitem = PostItem(
                  link: e.links![0].href!,
                  title: e.title ?? '',
                  rssTitle: atomFeed.title!,
                  description: e.summary ?? e.content ?? '',
                  pubDate: e.updated!);
              appendItem(postitem);
            }
            updateHTMLContent();
            if (mounted) {
              setState(() {});
            }
          }
        }
      } else {
        throw Exception('http error:${response.statusCode}');
      }
    } catch (ex) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('获取内容失败($url):$ex'),
      ));
    }
    loading.remove(url);
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
          ...loading.isNotEmpty
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
              name: 'hidden',
              onMessageReceived: (JavascriptMessage message) async {
                String key = message.message;
                setItemState(
                    DateTime.fromMillisecondsSinceEpoch(int.parse(key)),
                    PostState.psReaded);
                if (await Vibration.hasVibrator()) {
                  Vibration.vibrate();
                }
              }),
          JavascriptChannel(
              name: 'Print',
              onMessageReceived: (JavascriptMessage message) {
                // ignore: avoid_print
                print(message.message);
              }),
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
