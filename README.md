# UIWrapperPackage

A `WKWebView` container for hosting a web application inside a native iOS app.

It is one of the Swift packages used by **Digimaks**, a mobile digital wallet
continuing the work of the
[NOBID Consortium](https://www.nobidconsortium.com/) (the Nordic-Baltic eID
Project), one of the EU Large Scale Pilots preparing for eIDAS 2.0.

## Background

This package is the continuation of
[nobid-lsp-latvia/lx-ios-ui](https://github.com/nobid-lsp-latvia/lx-ios-ui),
developed within the NOBID Consortium and carried forward under the name
**Digimaks**.

## Requirements

- iOS 15+
- Swift 5.9+ / Xcode 15+

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "<repository-url>", from: "1.0.0")
```

or add it in Xcode via **File → Add Package Dependencies…**.

## Overview

| Type | Responsibility |
| ---- | -------------- |
| `WrapperView` | Configures and lays out the web view, disables zooming and forwards script messages |
| `WrapperMessageProtocol` | Receives messages posted from JavaScript to the native side |

Values interpolated into JavaScript must be escaped by the caller; the wrapper
does not sanitise them.

## Dependencies

- [SnapKit](https://github.com/SnapKit/SnapKit)

## Licence

Licensed under the [EUPL-1.2](LICENSE). See [Notice](Notice) for attribution.
