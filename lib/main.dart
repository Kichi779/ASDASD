import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  // CRASH ENGELLEME 1: Native bağlayıcıların hazır olduğundan emin oluyoruz.
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    log('FLUTTER ERROR', error: details.exception, stackTrace: details.stack);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uluslararası Alevi Vakfı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const WebViewPage(),
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
    _initApp();
  }

  // CRASH ENGELLEME 2: Başlatma işlemlerini tek bir güvenli fonksiyonda topladık.
  Future<void> _initApp() async {
    await _loadTheme();
    _setupController();
  }

  void _setupController() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => isLoading = true);
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() => isLoading = false);
            _injectTheme();
            await _checkCurrentUrl();
          },
          onWebResourceError: (error) {
            log("WEBVIEW ERROR: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(homeUrl));
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
        });
      }
    } catch (e) {
      log("PREFS LOAD ERROR: $e");
      // Eğer prefs hata verirse uygulama çökmez, varsayılan (false) ile devam eder.
    }
  }

  Future<void> _toggleTheme() async {
    try {
      setState(() => isDarkTheme = !isDarkTheme);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkTheme', isDarkTheme);
      _injectTheme();
    } catch (e) {
      log("PREFS SAVE ERROR: $e");
    }
  }

  void _injectTheme() {
    // Controller henüz hazır değilse işlem yapma (Crash engelleme)
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

    controller.runJavaScript(js).catchError((e) => log("JS Inject Error: $e"));
  }

  Future<void> _checkCurrentUrl() async {
    try {
      final currentUrl = await controller.currentUrl();
      if (!mounted) return;
      setState(() {
        if (currentUrl == null) {
          showSocialButtons = false;
        } else {
          showSocialButtons = currentUrl == homeUrl || currentUrl.startsWith(homeUrl);
        }
      });
    } catch (e) {
      log("URL Check Error: $e");
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      log("URL Launch Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea( // iOS çentiği için SafeArea ekledik
        child: Stack(
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
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "theme_btn", // Hero tag hatalarını önlemek için
            mini: true,
            backgroundColor: Colors.white.withOpacity(0.8),
            child: Icon(isDarkTheme ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          ),
          const SizedBox(height: 16),
          if (showSocialButtons) ...[
            _SocialButton(
              heroTag: "fb",
              color: const Color(0xFF1877F2),
              icon: Icons.facebook,
              onTap: () => _openUrl("https://www.facebook.com/alevivakfi"),
            ),
            _SocialButton(
              heroTag: "ig",
              color: const Color(0xFFE4405F),
              icon: Icons.camera_alt,
              onTap: () => _openUrl("https://www.instagram.com/alevitischestiftung/"),
            ),
            _SocialButton(
              heroTag: "yt",
              color: Colors.red,
              icon: Icons.play_arrow,
              onTap: () => _openUrl("https://www.youtube.com/@uadevakfi/videos"),
            ),
            _SocialButton(
              heroTag: "x_btn",
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
  final String heroTag;

  const _SocialButton({
    required this.color,
    this.icon,
    this.label,
    required this.onTap,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton(
        heroTag: heroTag,
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