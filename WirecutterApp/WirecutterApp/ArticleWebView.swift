import SwiftUI
import WebKit

struct ArticleWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        let hideHeaderCSS = """
        (function() {
            var style = document.createElement('style');
            style.textContent = `
                header,
                .global-header,
                .site-header,
                [data-testid="masthead"],
                [data-testid="site-header"],
                .NYTAppHideMasthead,
                #site-header,
                .css-1d8a7gp,
                nav[role="navigation"],
                .bottom-nav,
                .site-footer,
                footer,
                .ad,
                .ad-container,
                [id^="ad-"],
                .newsletter-signup,
                .nytc---modal-window---isShown {
                    display: none !important;
                }
                body {
                    padding-top: 0 !important;
                    margin-top: 0 !important;
                }
            `;
            document.head.appendChild(style);
        })();
        """

        let script = WKUserScript(
            source: hideHeaderCSS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let reapply = """
            setTimeout(function() {
                var headers = document.querySelectorAll('header, .global-header, .site-header, [data-testid="masthead"], [data-testid="site-header"], nav[role="navigation"], footer, .site-footer');
                headers.forEach(function(el) { el.style.display = 'none'; });
                document.body.style.paddingTop = '0';
            }, 500);
            """
            webView.evaluateJavaScript(reapply)
        }
    }
}
