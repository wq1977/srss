import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum PostState {
  psNew,
  psReaded,
  psFavorite,
}

class PostItem {
  final String title;
  final String description;
  final String link;
  final DateTime pubDate;
  final String rssTitle;
  const PostItem(
      {required this.link,
      required this.title,
      required this.description,
      required this.rssTitle,
      required this.pubDate});
}

List<String> urls = [];
Map<String, int> states = {};
Map<String, String> errors = {};
bool darkMode = false;

Future<void> init() async {
  final prefs = await SharedPreferences.getInstance();
  urls = prefs.getStringList('rss') ?? [];
  darkMode = prefs.getBool('darkmode') ?? false;
  states = Map<String, int>.from(jsonDecode(prefs.getString('state') ?? '{}'));
}

Future<bool> switchDarkMode() async {
  darkMode = !darkMode;
  final prefs = await SharedPreferences.getInstance();
  prefs.setBool('darkmode', darkMode);
  return darkMode;
}

setException(String url, String error) {
  errors[url] = error;
}

clearError(String url) {
  errors.remove(url);
}

removeRSS(String url) async {
  urls.remove(url);
  final prefs = await SharedPreferences.getInstance();
  prefs.setStringList('rss', urls);
}

addRSS(String url) async {
  if (!urls.contains(url)) {
    urls.add(url);
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('rss', urls);
  }
}

setItemState(DateTime timestamp, PostState state) async {
  String key = '${timestamp.millisecondsSinceEpoch}';
  if (states[key] != state.index) {
    states[key] = state.index;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('state', jsonEncode(states));
  }
}
