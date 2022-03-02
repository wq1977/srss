import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum PostState { psNew, psOld, psReaded, psFavorite, psBlocked }

List<String> urls = [];
Map<String, int> states = {};

Future<void> init() async {
  final prefs = await SharedPreferences.getInstance();
  urls = prefs.getStringList('rss') ?? [];
  states = Map<String, int>.from(jsonDecode(prefs.getString('state') ?? '{}'));
}

addRSS(String url) async {
  if (!urls.contains(url)) {
    urls.add(url);
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('rss', urls);
  }
}

setItemState(String url, PostState state) async {
  if (states[url] != state.index) {
    states[url] = state.index;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('state', jsonEncode(states));
  }
}
