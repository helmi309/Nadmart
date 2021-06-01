import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_offline/flutter_offline.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

_launchURL(url) async {
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}
DateTime currentBackPressTime;

class LoginScreen extends StatefulWidget {
  @override
  static const String id = "login_screen";

  _WebViewExampleState createState() => _WebViewExampleState();
}

WebViewController controllerGlobal;

Future<bool> _exitApp(BuildContext context) async {


  if (await controllerGlobal.canGoBack() && await controllerGlobal.currentUrl() != 'https://nadmartpo.com/') {

    controllerGlobal.goBack();
    // return Future.value(true);
  } else {
    if( await controllerGlobal.currentUrl() == 'https://nadmartpo.com/'){
      DateTime now = DateTime.now();
      if (currentBackPressTime == null ||
          now.difference(currentBackPressTime) > Duration(seconds: 5)) {
        currentBackPressTime = now;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('klik sekali lagi untuk keluar'),
          ),
        );
      }
      else{
        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      }
    }

  }
}

class _WebViewExampleState extends State<LoginScreen> {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();
  double webViewHeight;
   Timer _timer;
  final _key = UniqueKey();
  bool _load = false;

  @override
  void initState() {

    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: HexColor("#FFFFFF"),
      statusBarBrightness: Brightness.light
    ));
    return WillPopScope(
        onWillPop: () => _exitApp(context),
        child: Scaffold(
          appBar: PreferredSize(
              preferredSize: Size.fromHeight(0), // here the desired height
              child: AppBar(
                bottomOpacity: 0.0,
                elevation: 0.0,
                actions: <Widget>[
                  NavigationControls(_controller.future),
                ],
              )),
          body: OfflineBuilder(
              debounceDuration: Duration.zero,
              connectivityBuilder: (
                BuildContext context,
                ConnectivityResult connectivity,
                Widget child,
              ) {
                if (connectivity == ConnectivityResult.none) {
                  return Container(
                    color: Colors.white70,
                    child: Center(
                      child: Text(
                        'Oops, \n\nTidak Ada Koneksi Internet',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  );
                }
                return child;
              },

              child: Builder(builder: (BuildContext context) {
                return Stack(
                  children: <Widget>[
                    WebView(
                              initialUrl: 'https://nadmartpo.com/',
                              javascriptMode: JavascriptMode.unrestricted,
                              onPullToRefresh: () async {
                                controllerGlobal.reload();
                                return;
                              },

                              onWebViewCreated:
                                  (WebViewController webViewController) {
                                _controller.complete(webViewController);
                              },
                              onProgress: (int progress) {
                                setState((){
                                  _load=true;
                                });
                              if(progress == 100){
                                    return _timer = Timer(Duration(seconds: 3), () {
                                                setState((){
                                                  _load=false;
                                                });
                                    });
                              }
                                print(
                                    "WebView is loading (progress : $progress%)");
                              },
                              javascriptChannels: <JavascriptChannel>{
                                _toasterJavascriptChannel(context),
                              },
                              navigationDelegate: (NavigationRequest request) {
                                if (request.url
                                    .startsWith('https://youtube.com/')) {
                                  print('blocking navigation to $request}');
                                  return NavigationDecision.prevent;
                                }
                                if (request.url.contains("mailto:") || request.url.contains("tel:") || request.url.startsWith('https://api.whatsapp.com/')) {
                                  _launchURL(request.url);
                                  return NavigationDecision.prevent;
                                }
                                if(request.url == "https://api.whatsapp.com/send/"){
                                  Navigator.of(context).pop(); //close webview
                                }
                                print('allowing navigation to $request');
                                return NavigationDecision.navigate;
                              },
                              onPageStarted: (String url) {
                                print('Page started loading: $url');
                              },
                              onPageFinished: (String url) async  {
                                print('Page finished loading: $url');
                                  webViewHeight = double.tryParse(
                                      await controllerGlobal
                                      .evaluateJavascript("document.documentElement.scrollHeight;"),
                                  );
                                setState((){
                                  _load=false;
                                });

                                },
                              gestureNavigationEnabled: true,
                            ),
                    _load ? Center( child:  Scaffold(
                                              backgroundColor: Colors.white,
                                              body: Center(child: CircularProgressIndicator())))
                        : Stack(),
                  ]
                );
              })),
        ));
  }

  JavascriptChannel _toasterJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
        name: 'Toaster',
        onMessageReceived: (JavascriptMessage message) {
          // ignore: deprecated_member_use
          Scaffold.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        });
  }
}

class NavigationControls extends StatelessWidget {
  const NavigationControls(this._webViewControllerFuture)
      : assert(_webViewControllerFuture != null);

  final Future<WebViewController> _webViewControllerFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WebViewController>(
      future: _webViewControllerFuture,
      builder:
          (BuildContext context, AsyncSnapshot<WebViewController> snapshot) {
        final bool webViewReady =
            snapshot.connectionState == ConnectionState.done;
        final WebViewController controller = snapshot.data;
        controllerGlobal = controller;

        return Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: !webViewReady
                  ? null
                  : () async {
                      if (await controller.canGoBack()) {
                        controller.goBack();
                      } else {
                        Scaffold.of(context).showSnackBar(
                          const SnackBar(content: Text("No back history item")),
                        );
                        return;
                      }
                    },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: !webViewReady
                  ? null
                  : () async {
                      if (await controller.canGoForward()) {
                        controller.goForward();
                      } else {
                        Scaffold.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("No forward history item")),
                        );
                        return;
                      }
                    },
            ),
            IconButton(
              icon: const Icon(Icons.replay),
              onPressed: !webViewReady
                  ? null
                  : () {
                      controller.reload();
                    },
            ),
          ],
        );
      },
    );
  }
}
class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}
