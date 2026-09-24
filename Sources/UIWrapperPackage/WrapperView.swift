// SPDX-License-Identifier: EUPL-1.2

//
//  WrapperView.swift
//  UIWrapperPackage
//
//  Created by Matīss Mamedovs on 11/11/2024.
//

#if canImport(UIKit)


import UIKit
import WebKit
import SnapKit

public protocol WrapperMessageProtocol: Sendable {
    func messageReceived(interface: String, body: NSDictionary, from webView: WKWebView)
    func openExternalUrl(url: URL)
}

@MainActor public class WrapperView: UIView, UIScrollViewDelegate {
    
    fileprivate var resourcePath: String?
    fileprivate var webView: WKWebView?
    fileprivate var color: UIColor?
    fileprivate var interfaces: [String] = []
    public var delegate: WrapperMessageProtocol?
    
    fileprivate var route: String = "dashboard"
    fileprivate var params: String = ""
    fileprivate var baseURL: String = ""
    
    public convenience init(resourcePath: String, interfaces: [String], route: String, params: String, color: UIColor, baseURL: String) {
        self.init()
        
        self.resourcePath = resourcePath
        self.interfaces = interfaces
        self.route = route
        self.params = params
        self.color = color
        self.baseURL = baseURL
        setUp()
    }
    
    @MainActor fileprivate func setUp() {
        setupWebView()
        loadLocalHTML()
    }
    
    public func getWebView() -> WKWebView? {
        return self.webView
    }
}

extension WrapperView {
    fileprivate func setupWebView() {
        webView = WKWebView(frame: .zero, configuration: self.getWKWebViewConfiguration())
        webView?.isOpaque = false
        webView?.navigationDelegate = self
        webView?.scrollView.delegate = self
        webView?.backgroundColor = color
        if #available(iOS 16.4, *) {
            webView?.isInspectable = true
        } else {
            // Fallback on earlier versions
        }
        if let webView = webView {
            self.addSubview(webView)
            
            webView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
    
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
    
    private func getWKWebViewConfiguration() -> WKWebViewConfiguration {
        let source = "function captureLog(msg) { window.webkit.messageHandlers.logHandler.postMessage(msg); } window.console.log = captureLog;"
        let source1 = "var meta = document.createElement('meta');" +
        "meta.name = 'viewport';" +
        "meta.content = 'width=device-width, initial-scale=1.0, user-scalable=no, viewport-fit=cover';" +
        "var head = document.getElementsByTagName('head')[0];" +
        "head.appendChild(meta);"
        
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        let script1 = WKUserScript(source: source1, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        
        
        let userController = WKUserContentController()
        userController.addUserScript(script)
        userController.addUserScript(script1)
        for interface in self.interfaces {
            userController.add(self, name: interface)
        }
        
        
        userController.add(self, name: "settings")
        userController.add(self, name: "dashboard")
        userController.add(self, name: "onboarding")
        userController.add(self, name: "issuance")
        userController.add(self, name: "transactions")
        userController.add(self, name: "presentation")
        userController.add(self, name: "app")
        userController.add(self, name: "sign")
        userController.add(self, name: "logHandler")
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.userContentController = userController
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        return configuration
    }
    
    func getStatusBarHeight() -> CGFloat {
        var statusBarHeight: CGFloat = 0
        if #available(iOS 13.0, *) {
            let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            statusBarHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        } else {
            statusBarHeight = UIApplication.shared.statusBarFrame.height
        }
        return statusBarHeight + 4
    }
    
    func getBottomInset() -> CGFloat {
        if #available(iOS 13.0, *) {
            let window = UIApplication.shared.windows.first { $0.isKeyWindow }
            return window?.safeAreaInsets.bottom ?? 0
        } else {
            return UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
        }
    }
    
    @MainActor fileprivate func loadLocalHTML() {
        guard let resourcePath = resourcePath, let filePath = Bundle.main.url(forResource: resourcePath, withExtension: "html") else { return }
        
        var url = filePath.absoluteString
        url += "#/\(route)"
        if !self.params.isEmpty {
            url += "/" + self.params
        }
        if let destinationURL = URL(string: url) {
            print("Found file at path: \(filePath)")
            webView?.loadFileURL(destinationURL, allowingReadAccessTo: destinationURL.deletingLastPathComponent())
        } else {
            webView?.loadFileURL(filePath, allowingReadAccessTo: filePath.deletingLastPathComponent())
        }
    }
}

extension WrapperView: WKScriptMessageHandler, WKNavigationDelegate {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        guard let dictionary = body as? NSDictionary, let webView = webView else { return }
        self.delegate?.messageReceived(interface: message.name, body: dictionary, from: webView)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WEBVIEW: \(self.webView)")
        let height = self.getStatusBarHeight()
        let bottomInset = self.getBottomInset()
        self.webView?.evaluateJavaScript("document.documentElement.style.setProperty('--native-inset-top', '\(height)px');")
        self.webView?.evaluateJavaScript("document.documentElement.style.setProperty('--native-inset-bottom', '\(bottomInset)px');")
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let isUserGesture = navigationAction.navigationType == .linkActivated
        
        let absolute = url.absoluteString
        
        if !baseURL.isEmpty && (absolute.hasPrefix(self.baseURL) || absolute.hasPrefix("https://digimaks.eu")) {
            let modified = url.absoluteString
            guard let modifiedUrl = URL(string: modified) else { return }
            self.delegate?.openExternalUrl(url: modifiedUrl)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
}

#endif
