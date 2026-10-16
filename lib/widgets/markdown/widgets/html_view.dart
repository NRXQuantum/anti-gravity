import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart';
import 'package:chatmcp/generated/app_localizations.dart';

class HtmlView extends StatefulWidget {
  final String html;
  final bool autoHeight;

  const HtmlView({super.key, required this.html, this.autoHeight = true});

  @override
  State<HtmlView> createState() => _HtmlViewState();
}

class _HtmlViewState extends State<HtmlView> {
  double _height = 300;
  InAppWebViewController? controller;
  bool _hasError = false;
  int _retryCount = 0;
  static const int maxRetries = 3;

  Key _webViewKey = UniqueKey();

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  String _prepareHtml(String raw) {
    String content = raw.trim();
    if (content.isEmpty) return content;

    // If it's SVG without HTML wrapper
    if ((content.startsWith('<svg') || content.contains('<svg')) && !content.toLowerCase().contains('<html')) {
      return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">
  <style>
    body {
      margin: 0;
      padding: 16px;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      background: transparent;
    }
    svg {
      max-width: 100%;
      height: auto;
    }
  </style>
</head>
<body>
  $content
</body>
</html>''';
    }

    // If it's full HTML, ensure viewport meta tag exists if missing
    if (content.toLowerCase().contains('<html')) {
      if (!content.toLowerCase().contains('viewport') && content.toLowerCase().contains('<head>')) {
        content = content.replaceFirst(
          RegExp(r'<head>', caseSensitive: false),
          '<head><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">',
        );
      }
      return content;
    }

    // HTML snippet / fragment
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      padding: 12px;
      margin: 0;
      background: transparent;
    }
    canvas {
      max-width: 100%;
      height: auto;
    }
  </style>
</head>
<body>
  $content
</body>
</html>''';
  }

  Future<void> _initWebView(InAppWebViewController controller) async {
    this.controller = controller;
    try {
      await controller.loadData(
        data: _prepareHtml(widget.html),
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri('about:blank'),
      );
    } catch (e) {
      debugPrint('Error loading WebView data: $e');
      _handleError();
    }
  }

  void _handleError() {
    if (_retryCount < maxRetries) {
      _retryCount++;
      _resetWebView();
    } else {
      setState(() => _hasError = true);
    }
  }

  void _resetWebView() {
    controller?.dispose();
    controller = null;
    setState(() => _webViewKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    var t = AppLocalizations.of(context)!;
    if (_hasError) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.loadContentFailed),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _retryCount = 0;
                  });
                  _resetWebView();
                },
                child: Text(t.retry),
              ),
            ],
          ),
        ),
      );
    }

    final webView = InAppWebView(
      key: _webViewKey,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        transparentBackground: true,
        isInspectable: kDebugMode,
        domStorageEnabled: true,
        databaseEnabled: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        supportZoom: true,
        builtInZoomControls: false,
        displayZoomControls: false,
        allowFileAccess: true,
        allowContentAccess: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      onWebViewCreated: (controller) => _initWebView(controller),
      onLoadStop: (controller, url) async {
        if (!widget.autoHeight) return;
        try {
          final result = await controller.evaluateJavascript(
            source: 'Math.max(document.body ? document.body.scrollHeight : 0, document.documentElement ? document.documentElement.scrollHeight : 0, 300)',
          );
          if (result != null && result is num && mounted) {
            final newHeight = result.toDouble();
            if (newHeight > 50 && (_height - newHeight).abs() > 10) {
              setState(() => _height = newHeight);
            }
          }
        } catch (e) {
          debugPrint('Error on load stop: $e');
        }
      },
      onCreateWindow: (controller, request) => Future.value(false),
      onReceivedError: (controller, request, error) {
        debugPrint('WebView error: ${error.description}');
        _handleError();
      },
    );

    if (!widget.autoHeight) {
      return webView;
    }

    return SizedBox(
      height: _height,
      child: webView,
    );
  }
}

/// Helper function to wrap standalone JavaScript into an interactive HTML preview
String wrapJsInHtml(String jsCode) {
  return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background: #ffffff;
      color: #212529;
    }
    #root, #app {
      min-height: 50px;
    }
    canvas {
      max-width: 100%;
      height: auto;
      display: block;
      margin: 10px 0;
      border: 1px solid #dee2e6;
      border-radius: 6px;
    }
    .console-panel {
      margin-top: 20px;
      background: #1e1e2e;
      color: #cdd6f4;
      border-radius: 8px;
      overflow: hidden;
      font-family: monospace;
      font-size: 13px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }
    .console-header {
      background: #181825;
      padding: 8px 12px;
      font-size: 11px;
      font-weight: bold;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: #a6adc8;
      border-bottom: 1px solid #313244;
    }
    .console-body {
      padding: 10px 12px;
      max-height: 250px;
      overflow-y: auto;
    }
    .console-entry {
      padding: 3px 0;
      border-bottom: 1px solid rgba(255,255,255,0.05);
      white-space: pre-wrap;
      word-break: break-all;
    }
    .console-entry.log { color: #a6e3a1; }
    .console-entry.info { color: #89b4fa; }
    .console-entry.warn { color: #f9e2af; }
    .console-entry.error { color: #f38ba8; }
  </style>
</head>
<body>
  <div id="root"></div>
  <div id="app"></div>
  <div id="console-panel" class="console-panel" style="display: none;">
    <div class="console-header">Console Output</div>
    <div id="console-body" class="console-body"></div>
  </div>
  <script>
    (function() {
      const panel = document.getElementById('console-panel');
      const container = document.getElementById('console-body');
      function addEntry(level, args) {
        panel.style.display = 'block';
        const div = document.createElement('div');
        div.className = 'console-entry ' + level;
        div.textContent = '[' + level.toUpperCase() + '] ' + args.map(arg => {
          if (typeof arg === 'object' && arg !== null) {
            try { return JSON.stringify(arg, null, 2); } catch(e) { return String(arg); }
          }
          return String(arg);
        }).join(' ');
        container.appendChild(div);
      }
      const _log = console.log, _warn = console.warn, _error = console.error, _info = console.info;
      console.log = function(...args) { _log.apply(console, args); addEntry('log', args); };
      console.info = function(...args) { _info.apply(console, args); addEntry('info', args); };
      console.warn = function(...args) { _warn.apply(console, args); addEntry('warn', args); };
      console.error = function(...args) { _error.apply(console, args); addEntry('error', args); };
      window.onerror = function(msg, url, line) {
        addEntry('error', [msg + ' (line ' + line + ')']);
        return false;
      };
    })();
  </script>
  <script>
try {
$jsCode
} catch (e) {
  console.error(e.message || String(e));
}
  </script>
</body>
</html>''';
}

/// Helper function to wrap standalone CSS into an HTML preview showcasing styled elements
String wrapCssInHtml(String cssCode) {
  return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">
  <style>
$cssCode
  </style>
</head>
<body>
  <div class="container preview-container">
    <div class="card preview-card">
      <h1 class="title">Styled Heading</h1>
      <p class="description">This preview showcases styles defined in the CSS.</p>
      <div class="button-group">
        <button class="btn btn-primary button">Primary Button</button>
        <button class="btn btn-secondary button">Secondary Button</button>
      </div>
      <div class="box preview-box" style="margin-top: 15px; padding: 12px; border: 1px dashed #ccc; border-radius: 6px;">
        Sample Styled Box
      </div>
    </div>
  </div>
</body>
</html>''';
}

