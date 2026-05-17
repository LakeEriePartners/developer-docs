---
title: Connect SDK Quickstart
sidebar_label: Quickstart
---

# Connect SDK Quickstart

The fastest way to see the SDK working is to copy one of the snippets
below into a page, run it in `isDemo: true` mode, and watch the wizard
render. Swap in your real `apiToken` and `tenant` / `employer`
identifiers when you're ready to leave demo mode.

For every configuration option and lifecycle callback, see the
[SDK Reference](/sdk/).

## npm (recommended)

```bash
npm install stream-connect-sdk
```

```javascript
import StreamConnect from "stream-connect-sdk";

const sdk = StreamConnect({
  el: "#react-hook",
  isDemo: true,
});
```

## Hosted CDN

```html
<script src="https://app.tpastream.com/static/js/sdk.js"></script>
<script>
  window.StreamConnect({
    el: "#react-hook",
    tenant: {
      systemKey: "test",
      vendor: "internal",
    },
    employer: {
      systemKey: "some-system-key",
      vendor: "internal",
      name: "some-name",
    },
    user: {
      firstName: "Joe",
      lastName: "Sajor",
      email: "some-email@place.com",
      memberSystemKey: "some-system-key",
      phoneNumber: "333333333",
      dateOfBirth: "11-11-1121",
    },
    apiToken: "Some Provided Key", // TPA Stream provides this
    isDemo: false,
    realTimeVerification: true,
    renderChoosePayer: true,
    doneGetSDK: ({ user, payers, tenant, employer }) => {},
    doneChoosePayer: ({ choosePayer, streamPayers }) => {},
    doneTermsOfService: () => {},
    doneCreatedForm: () => {},
    donePostCredentials: ({ params }) => {},
    doneRealTime: () => {},
    donePopUp: () => {},
    doneEasyEnroll: ({ employer, payer, tenant, policyHolder, user }) => {},
    handleFormErrors: (error, { response, request, config }) => {},
    userSchema: {},
  });
</script>
```

### Pinning a CDN version

As of SDK 0.4.7, the CDN provider is versioned. The script tag's `src`
selects the version:

- `https://app.tpastream.com/static/js/sdk.js` — latest
- `https://app.tpastream.com/static/js/sdk-v-<VersionNumber>.js` — a
  specific version, e.g. `sdk-v-0.4.7.js`

## Android (WebView)

Put an HTML file in your `assets/` folder that loads the SDK, then
load it in a WebView:

```java
public class ViewWeb extends Activity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.content);
        WebView webview = (WebView) findViewById(R.id.webView);
        webview.loadUrl("file:///android_asset/stream-connect.html");
    }
}
```

## iOS (WKWebView)

Put an HTML file (here `index.html` in a `stream-connect` directory)
in your bundle, then load it in a WKWebView:

```objective-c
import UIKit
import WebKit

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    @IBOutlet weak var webView: WKWebView!
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.uiDelegate = self
        webView.navigationDelegate = self
        let url = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "stream-connect"
        )!
        webView.loadFileURL(url, allowingReadAccessTo: url)
        let request = URLRequest(url: url)
        webView.load(request)
    }
}
```
