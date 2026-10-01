# ShareFreezeRepro

A minimal UIKit app that reproduces an iOS bug: **after sharing through the system share sheet to an app that comes to the foreground, and then returning, the original app stops receiving touches.** The screen keeps drawing and the main thread keeps running, but taps never arrive.

This repository contains the reproduction app and what we learned while investigating. We are publishing it so that developers who run into the same problem do not have to repeat the same dead ends.

## How this was found

This was investigated by a non-engineer indie developer working together with AI (Anthropic's Claude). The person ran every test on a real device and made the observations. The AI proposed hypotheses, wrote the instrumentation, and interpreted the results.

It came up while building a small transcription app. The share sheet froze the app, and the freeze turned out to have nothing to do with that app's code.

**Please read the findings with that in mind.** They were checked carefully, but they come from one device and one OS version, and they may contain mistakes.

## Scope of testing

- **Device:** iPhone 12 mini
- **OS:** iOS 26.6
- Nothing else was tested by us. Reports from other people on other versions are linked at the end.

## The symptom

1. Open the share sheet (`UIActivityViewController`).
2. Share to an app that opens in the foreground (for example, Claude, ChatGPT, or Gemini).
3. Return to the original app (for example, with the "◀ AppName" back button in the status bar).
4. The original app no longer responds to any touch.

The screen is not frozen: animations and a running clock keep updating, and the main thread is idle and waiting for events as usual. Relaunching the app usually recovers it. **Sometimes the device itself had to be restarted.**

## What the reproduction app shows

The app has only a few buttons and a share sheet. It uses no SwiftUI, no audio session, and no extra windows. A `UIApplication` subclass counts calls to `sendEvent:` and shows the count on screen together with a clock, so **the state can be read from the frozen screen without a debugger.**

All three item types we tried froze on the first attempt. After the freeze, the clock keeps ticking and the `sendEvent:` count stops increasing.

## What we found

1. **Touches do not reach the app's process.** `-[UIApplication sendEvent:]` is not called at all, even when tapping blank areas. We confirmed this both with the on-screen counter and with a breakpoint in lldb.

2. **UI hosted by another process still receives touches; the app's own views do not.** In the frozen state:
   - The software keyboard (drawn by another process) could still be used and dismissed.
   - A document picker presented on return could be scrolled, navigated, and cancelled.
   - In the Files app, the Quick Look preview content could still be scrolled.
   - Meanwhile, the app's own buttons and views received nothing, and the `sendEvent:` count did not change.
   
   Dismissing the document picker by hand did **not** restore touch delivery.

3. **It is not caused by the app's code.** It reproduces in this minimal UIKit app. Apple's Notes app showed the same pattern: its own controls stopped responding, while typing through the keyboard still worked.

4. **What did not matter:** how you return (back button or app switcher), the type of item shared, and which app presents the share sheet.

5. **Which receiving app triggers it is not stable.** On our device, the set of receiving apps that caused the freeze changed after simply installing one more app. We could not find a receiving app that is reliably safe.

6. **It is not specific to debug builds.** An App Store–signed release build behaved the same way.

7. **Sharing that does not bring another app to the foreground did not trigger it.** "Save to Files" from the same share sheet worked without freezing.

## Workarounds we tried (none worked)

- Presenting the share sheet directly from UIKit with a completion handler, instead of SwiftUI's `.sheet`.
- On returning to the app, presenting a document picker and dismissing it shortly afterwards.
- On returning to the app, making a hidden text field the first responder to bring up the keyboard.
- Routing the share through an intermediate app.

Other developers have reported that presenting the share sheet from a dedicated, temporary window fixed an older iOS 16 issue but did not help on iOS 26 (see the expo issue below).

Given finding 2, we believe no in-app workaround is possible: an app's own interface is made of its own views, and those are exactly what stop receiving touches. **This is our interpretation, not a confirmed cause.** We do not know which part of the system is responsible.

## What we did in our own app

We stopped relying on the share sheet for handing text to other apps. We switched to copying the text to the clipboard and offering "Save to Files". The share sheet is still available, but we do not guarantee it works with every receiving app.

## Other reports

- [iOS 27: Returning back to in-app Share Sheet from ChatGPT freezes host app](https://randomipad.blogspot.com/2026/09/ios-27-returning-back-to-in-app-share.html) — iOS 27, iPhone 17. Suggests the problem is still present in iOS 27. (We have not tested iOS 27 ourselves.)
- [expo/expo #43774](https://github.com/expo/expo/issues/43774) — iOS 26.2 and later.
- Apple Developer Forums thread 817027 — iOS 26.3.

## Building

Open the project in Xcode, choose your own development team, and run it on a device. The bundle ID is `com.example.ShareFreezeRepro`; change it if needed. The bug does not reproduce in the Simulator.

The Xcode project is generated from project.yml with XcodeGen. You can open the included project directly, or edit project.yml and regenerate it.

## Using this material

**We do not plan to contact Apple about this ourselves.** Please feel free to use this repository and these findings in any way: attach them to your own Feedback reports, quote them, adapt the app, or build on the investigation. No permission or credit is required.

We are not able to provide support or follow up on questions.

License: MIT (see `LICENSE`).

---

## 日本語の要約

共有シートから、前面に開くアプリ（Claude・ChatGPT・Gemini など）へ渡して戻ると、元のアプリにタッチが一切届かなくなる iOS の不具合の再現アプリと、調べた結果です。

非エンジニアの個人開発者が、AI（Anthropic の Claude）と一緒に調べました。実機での操作と観察は人が、仮説・計測の仕組み・結果の読み解きは AI が担いました。確かめたのは iPhone 12 mini・iOS 26.6 だけです。

分かったことの要点は、タッチがアプリのプロセスまで届いていないこと、別プロセスが描く UI（キーボード・ファイル選択画面など）には届くのにアプリ自身のビューには届かないこと、アプリ側の回避策はどれも効かなかったことです。

Apple とのやり取りは予定していません。この記録と再現アプリは、Feedback への添付・引用・作り直しなど、自由に使ってください。
