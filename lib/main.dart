import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:prompt_dialog/prompt_dialog.dart';
import 'package:srss/const.dart';
import 'package:srss/model.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

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

  String item2json(PostItem item) {
    return jsonEncode({
      "title": item.title,
      "description": item.description,
      "link": item.link,
      "pubDate": item.pubDate.millisecondsSinceEpoch,
      "rssTitle": item.rssTitle
    });
  }

  appendItem(PostItem item) async {
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
      var controller = await _controller.future;
      String script = "appendItem(${item2json(item)})";
      // print(script);
      controller.runJavascript(script);
    }
    // items.sort((a, b) =>
    //     b.pubDate.millisecondsSinceEpoch - a.pubDate.millisecondsSinceEpoch);
  }

  static const String htmlHeader = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
$css
</style>
<script>

window.switchDarkMode = function(mode) {
  if (mode) {
    document.documentElement.classList.remove('light')
    document.documentElement.classList.add('dark')
    document.documentElement.style['color-scheme'] = 'dark'
  } else {
    document.documentElement.classList.remove('dark')
    document.documentElement.classList.add('light')
    document.documentElement.style['color-scheme'] = 'light'
  }
}

window.appendItem = function (item) {
  var d = document.createElement("div");
  d.className = 'srss_post_item'
  d.setAttribute('data-link', item.pubDate)
  d.setAttribute('data-title', item.title)
  d.onclick = ()=>{router.postMessage(item.link);}
  d.innerHTML = "<h1>"+item.title + "</h1>" +
                "<div>" + item.rssTitle + "</div>" +
                "<div>" + (item.description.indexOf('<p>') >= 0 ? item.description : ('<p>' + item.description + '</p>')) + "</div>";
  document.body.appendChild(d)              
}

// setInterval(()=>{
//   // Print.postMessage(`\${window.pageYOffset} || \${document.documentElement.scrollTop} || \${document.body.scrollTop}`);
// }, 1000)

window.addEventListener('scroll', function() {
  if (window.scrollendWatchTimer) {
    clearTimeout(window.scrollendWatchTimer)
  }
  window.scrollendWatchTimer = setTimeout(()=>{
    window.scrollendWatchTimer=null
    const nodes = document.querySelectorAll('.srss_post_item')
    Print.postMessage(nodes.length)
    const readed = []
    for (var i=0;i<nodes.length;i++) {
      const node = nodes[i]
      const link = node.getAttribute('data-link')
      const rect = node.getBoundingClientRect()
      if (rect.bottom < 0) {
        readed.push(link)
      }
    }
    hidden.postMessage(readed.join(","))
  }, 1000)
});
</script>
</head>
<body>
''';
  static const String htmlEnd = '''
</body>
</html>
''';
  getHTMLContent() {
    return htmlHeader + htmlEnd;
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
          IconButton(
              onPressed: () async {
                bool mode = await switchDarkMode();
                var controller = await _controller.future;
                controller.runJavascript('switchDarkMode($mode)');
                setState(() {});
              },
              icon: Icon(darkMode
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined)),
          IconButton(onPressed: addAnRSS, icon: const Icon(Icons.add_card))
        ],
      ),
      body: WebView(
        initialUrl: 'about:blank', //getHTMLContent(),
        debuggingEnabled: false, //turn on to debug from chrome
        onWebViewCreated: (WebViewController webViewController) async {
          await webViewController.loadHtmlString(getHTMLContent());
          await Future.delayed(const Duration(milliseconds: 100));
          await webViewController.runJavascript('switchDarkMode($darkMode)');
          _controller.complete(webViewController);
        },
        javascriptMode: JavascriptMode.unrestricted,
        javascriptChannels: {
          JavascriptChannel(
              name: 'hidden',
              onMessageReceived: (JavascriptMessage message) async {
                List<String> keys = message.message.split(",");
                for (var key in keys) {
                  if (states[key] == PostState.psNew.index) {
                    setItemState(
                        DateTime.fromMillisecondsSinceEpoch(int.parse(key)),
                        PostState.psReaded);
                    bool canVibrate = await Vibrate.canVibrate;
                    if (canVibrate) {
                      Vibrate.feedback(FeedbackType.light);
                    }
                    break;
                  }
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
