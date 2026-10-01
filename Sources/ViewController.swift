import UIKit
import UniformTypeIdentifiers

final class ViewController: UIViewController {
    // 画面最上部(safe area直下)の1行ステータス: ページシート提示中も読める位置。
    // 形式: "HH:mm:ss T:n D:n | 要求:n 提示:… 解除:…"
    private let topStatusLabel = UILabel()
    // 画面中央の詳細表示(提示前・解除後のスクリーンショット用のフルテキスト)
    private let detailLabel = UILabel()
    private let autoCloseSwitch = UISwitch()
    private var timer: Timer?
    private var didShare = false
    private var pickerRequestCount = 0
    private var pickerPresentResult = "未"
    private var pickerDismissResult = "未"
    private var clockText = "--:--:--"
    private static let autoCloseKey = "pickerAutoClose"
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        topStatusLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        topStatusLabel.textAlignment = .center
        topStatusLabel.adjustsFontSizeToFitWidth = true
        topStatusLabel.minimumScaleFactor = 0.6
        topStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topStatusLabel)
        NSLayoutConstraint.activate([
            topStatusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 2),
            topStatusLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            topStatusLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
        ])

        detailLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        let fileButton = makeButton(title: "ファイル(.md)を共有", action: #selector(shareFile))
        let imageButton = makeButton(title: "画像(UIImage)を共有", action: #selector(shareImage))
        let textButton = makeButton(title: "文字列を共有", action: #selector(shareText))

        // 復帰時ピッカーの自動クローズ切り替え(固まる前に設定できる位置)。既定オフ=出したまま
        let switchLabel = UILabel()
        switchLabel.text = "ピッカーを自動で閉じる(0.8秒)"
        switchLabel.font = .systemFont(ofSize: 15)
        switchLabel.adjustsFontSizeToFitWidth = true
        autoCloseSwitch.isOn = UserDefaults.standard.bool(forKey: Self.autoCloseKey)
        autoCloseSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        let switchRow = UIStackView(arrangedSubviews: [switchLabel, autoCloseSwitch])
        switchRow.axis = .horizontal
        switchRow.spacing = 8

        let stack = UIStackView(arrangedSubviews: [detailLabel, fileButton, imageButton, textButton, switchRow])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
        ])

        render()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.clockText = self.formatter.string(from: Date())
            self.render()
        }
        NotificationCenter.default.addObserver(forName: .init("eventCounted"), object: nil, queue: .main) { [weak self] _ in
            self?.render()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleDidBecomeActive()
        }
    }

    @objc private func switchChanged() {
        UserDefaults.standard.set(autoCloseSwitch.isOn, forKey: Self.autoCloseKey)
    }

    // 復帰時: 共有を出した後の最初のactive復帰で書類ピッカーを提示。
    // 成否は完了ハンドラ+presentedViewController実測で記録し、推測で埋めない。
    private func handleDidBecomeActive() {
        guard didShare else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            if self.presentedViewController != nil {
                self.pickerPresentResult = "スキップ(提示中VCあり)"
                self.render()
                return
            }
            self.didShare = false
            self.pickerRequestCount += 1
            self.pickerPresentResult = "要求済・完了H未着"
            self.pickerDismissResult = "未"
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
            picker.delegate = self
            picker.presentationController?.delegate = self
            self.present(picker, animated: true) { [weak self] in
                guard let self else { return }
                let onScreen = (self.presentedViewController === picker)
                self.pickerPresentResult = onScreen ? "OK(完了H+presented確認)" : "完了Hのみ(presented不一致)"
                self.render()
            }
            self.render()
            if self.autoCloseSwitch.isOn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    picker.dismiss(animated: true) {
                        self?.pickerDismissResult = "自動(完了H)"
                        self?.render()
                    }
                }
            }
        }
    }

    private func render() {
        let t = "\(clockText) T:\(CountingApplication.tapCount) D:\(CountingApplication.dragCount) | 要求:\(pickerRequestCount) 提示:\(pickerPresentResult) 解除:\(pickerDismissResult)"
        topStatusLabel.text = t
        detailLabel.text = "sendEvent タップ:\(CountingApplication.tapCount) ドラッグ:\(CountingApplication.dragCount)\nピッカー提示要求: \(pickerRequestCount)回\n提示成否: \(pickerPresentResult)\n解除検知: \(pickerDismissResult)"
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.buttonSize = .large
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func shareFile(_ sender: UIButton) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("repro.md")
        let body = "# 共有テスト\n\nこれは最小再現アプリが書き出したMarkdownファイルです。\n"
        try? body.write(to: url, atomically: true, encoding: .utf8)
        presentShare(items: [url], from: sender)
    }

    @objc private func shareImage(_ sender: UIButton) {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        let image = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
            let text = "repro" as NSString
            text.draw(at: CGPoint(x: 140, y: 180), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 40),
                .foregroundColor: UIColor.white,
            ])
        }
        presentShare(items: [image], from: sender)
    }

    @objc private func shareText(_ sender: UIButton) {
        presentShare(items: ["共有テスト文字列(最小再現アプリ)"], from: sender)
    }

    private func presentShare(items: [Any], from sender: UIButton) {
        didShare = true
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = sender
        present(vc, animated: true)
    }
}

extension ViewController: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pickerDismissResult = "キャンセル(delegate)"
        render()
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        pickerDismissResult = "選択(delegate)"
        render()
    }
}

extension ViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        pickerDismissResult = "スワイプ(didDismiss)"
        render()
    }
}
