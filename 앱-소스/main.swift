import Cocoa
import WebKit

// 저장 파일 위치: ~/Library/Application Support/졸업 커리큘럼 플래너/data.json
let appName = "졸업 커리큘럼 플래너"
let dataDir: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = base.appendingPathComponent(appName, isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}()
let dataFile = dataDir.appendingPathComponent("graduation-curriculum-planner.json")
// 예전 이름(data.json)으로 저장돼 있으면 새 이름으로 옮김
let legacyFile = dataDir.appendingPathComponent("data.json")
if !FileManager.default.fileExists(atPath: dataFile.path), FileManager.default.fileExists(atPath: legacyFile.path) {
    try? FileManager.default.moveItem(at: legacyFile, to: dataFile)
}

// 투명해진 제목 줄 자리에 얹는 "창 끌기 손잡이"
final class DragStrip: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { window?.performZoom(nil) }      // 제목 줄 더블클릭 = 확대/복원
        else { window?.performDrag(with: event) }                   // 끌면 창 이동
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler, WKDownloadDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(self, name: "store")

        // 저장된 데이터를 페이지가 뜨기 전에 주입
        if let data = try? Data(contentsOf: dataFile), let json = String(data: data, encoding: .utf8) {
            let script = WKUserScript(source: "window.__initialState = \(json);", injectionTime: .atDocumentStart, forMainFrameOnly: true)
            controller.addUserScript(script)
        }
        // 페이지가 "맥 앱 안"임을 알 수 있도록 표시 (상단 바 여백 처리용)
        controller.addUserScript(WKUserScript(source: "document.documentElement.classList.add('mac-app');", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController = controller

        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")   // 로딩 중 흰 화면 깜빡임 방지

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 820),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = appName
        // 상단 바를 투명하게 해서 앱 UI와 한 덩어리로 보이게
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = .windowBackgroundColor
        window.minSize = NSSize(width: 720, height: 480)
        window.center()
        window.setFrameAutosaveName("MainWindow")
        // 웹 화면 위에, 맨 위 36pt 띠만 덮는 드래그 손잡이를 얹음 (헤더 여백과 같은 높이)
        let container = NSView(frame: window.contentLayoutRect)
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
        let stripH: CGFloat = 36
        let strip = DragStrip(frame: NSRect(x: 0, y: container.bounds.height - stripH, width: container.bounds.width, height: stripH))
        strip.autoresizingMask = [.width, .minYMargin]
        container.addSubview(strip, positioned: .above, relativeTo: webView)
        window.contentView = container
        window.makeKeyAndOrderFront(nil)

        let url = Bundle.main.url(forResource: "index", withExtension: "html")!
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: 저장 (JS -> 파일)
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "store", let json = message.body as? String else { return }
        try? json.data(using: .utf8)?.write(to: dataFile, options: .atomic)
    }

    // MARK: alert / confirm
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = NSAlert(); a.messageText = message; a.addButton(withTitle: "확인")
        a.beginSheetModal(for: window) { _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = NSAlert(); a.messageText = message
        a.addButton(withTitle: "확인"); a.addButton(withTitle: "취소")
        a.beginSheetModal(for: window) { r in completionHandler(r == .alertFirstButtonReturn) }
    }

    // MARK: 불러오기 (파일 선택창)
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let p = NSOpenPanel()
        p.allowsMultipleSelection = false
        p.allowedContentTypes = [.json]
        p.beginSheetModal(for: window) { r in completionHandler(r == .OK ? p.urls : nil) }
    }

    // MARK: 내보내기 (다운로드 -> 저장창)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload { decisionHandler(.download) } else { decisionHandler(.allow) }
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let p = NSSavePanel()
        p.nameFieldStringValue = suggestedFilename
        p.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        p.beginSheetModal(for: window) { r in
            if r == .OK, let url = p.url { try? FileManager.default.removeItem(at: url); completionHandler(url) }
            else { completionHandler(nil) }
        }
    }

    // MARK: 메뉴 (Cmd+Q, Cmd+W, 복사/붙여넣기)
    func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "\(appName) 정보", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "저장 폴더 열기", action: #selector(openDataFolder), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "\(appName) 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem(); main.addItem(fileItem)
        let fileMenu = NSMenu(title: "파일")
        fileMenu.addItem(withTitle: "윈도우 닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu

        let editItem = NSMenuItem(); main.addItem(editItem)
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "실행 복귀", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "오려두기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        let viewItem = NSMenuItem(); main.addItem(viewItem)
        let viewMenu = NSMenu(title: "보기")
        viewMenu.addItem(withTitle: "다시 불러오기", action: #selector(reloadPage), keyEquivalent: "r")
        viewItem.submenu = viewMenu

        let windowItem = NSMenuItem(); main.addItem(windowItem)
        let windowMenu = NSMenu(title: "윈도우")
        windowMenu.addItem(withTitle: "최소화", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = main
    }
    @objc func openDataFolder() { NSWorkspace.shared.activateFileViewerSelecting([dataFile]) }
    @objc func showAbout() {
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let credits = NSMutableAttributedString()
        credits.append(NSAttributedString(string: "Made with ❤️ by Claude\n", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .paragraphStyle: para, .foregroundColor: NSColor.labelColor]))
        credits.append(NSAttributedString(string: "Anthropic의 Claude가 2026년 10월에 만든 개인용 졸업 플래너입니다.\n저장 파일: graduation-curriculum-planner.json", attributes: [
            .font: NSFont.systemFont(ofSize: 11), .paragraphStyle: para, .foregroundColor: NSColor.secondaryLabelColor]))
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: appName,
            .applicationVersion: "1.0",
            .version: "",
            .credits: credits
        ])
    }
    @objc func reloadPage() {
        // 저장 데이터를 다시 주입한 뒤 새로고침
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        if let data = try? Data(contentsOf: dataFile), let json = String(data: data, encoding: .utf8) {
            controller.addUserScript(WKUserScript(source: "window.__initialState = \(json);", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        webView.reload()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
