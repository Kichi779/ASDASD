// lib/main.dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    log('FLUTTER ERROR', error: details.exception, stackTrace: details.stack);
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Uluslararası Alevi Vakfı',
      debugShowCheckedModeBanner: false,
      home: WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;

  bool isDarkTheme = false;
  bool showSocialButtons = true;
  bool isLoading = true;

  static const String homeUrl = "https://www.alevi-vakfi.com/";

  @override
  void initState() {
    super.initState();
    _loadTheme();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            log("PAGE STARTED: $url");
            if (mounted) {
              setState(() => isLoading = true);
            }
          },
          onPageFinished: (url) async {
            log("PAGE FINISHED: $url");
            if (!mounted) return;

            setState(() => isLoading = false);
            _injectTheme();
            await _checkCurrentUrl();
          },
          onWebResourceError: (error) {
            log(
              "WEBVIEW ERROR",
              error: error.description,
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(homeUrl));
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    });
  }

  Future<void> _toggleTheme() async {
    setState(() => isDarkTheme = !isDarkTheme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', isDarkTheme);
    _injectTheme();
  }

  void _injectTheme() {
    final String js = isDarkTheme
        ? """
        (function() {
          if (document.getElementById('dark-style')) return;
          var s = document.createElement('style');
          s.id = 'dark-style';
          s.innerHTML = `
            body { background:#121212 !important; color:#fff !important; }
            * { color:#fff !important; background:#121212 !important; }
            a { color:#bb86fc !important; }
            input,textarea,select { background:#333 !important; color:#fff !important; }
          `;
          document.head.appendChild(s);
        })();
        """
        : """
        (function() {
          var s = document.getElementById('dark-style');
          if (s) s.remove();
        })();
        """;

    controller.runJavaScript(js);
  }

  Future<void> _checkCurrentUrl() async {
    final currentUrl = await controller.currentUrl();
    log("CURRENT URL: $currentUrl");

    if (!mounted) return;

    setState(() {
      if (currentUrl == null) {
        showSocialButtons = false;
      } else {
        showSocialButtons =
            currentUrl == homeUrl || currentUrl.startsWith(homeUrl);
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.purple),
                  SizedBox(height: 20),
                  Text(
                    "Yükleniyor...",
                    style: TextStyle(color: Colors.purple, fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white.withOpacity(0.8),
            child: Icon(isDarkTheme ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          ),
          const SizedBox(height: 16),
          if (showSocialButtons) ...[
            _SocialButton(
              color: const Color(0xFF1877F2),
              icon: Icons.facebook,
              onTap: () => _openUrl("https://www.facebook.com/alevivakfi"),
            ),
            _SocialButton(
              color: const Color(0xFFE4405F),
              icon: Icons.camera_alt,
              onTap: () => _openUrl(
                  "https://www.instagram.com/alevitischestiftung/"),
            ),
            _SocialButton(
              color: Colors.red,
              icon: Icons.play_arrow,
              onTap: () =>
                  _openUrl("https://www.youtube.com/@uadevakfi/videos"),
            ),
            _SocialButton(
              color: Colors.black,
              label: "X",
              onTap: () => _openUrl("https://x.com/UADEVAKFI"),
            ),
            const SizedBox(height: 80),
          ],
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String? label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.color,
    this.icon,
    this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton(
        mini: true,
        backgroundColor: color,
        onPressed: onTap,
        child: icon != null
            ? Icon(icon, color: Colors.white)
            : Text(
          label ?? '',
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
