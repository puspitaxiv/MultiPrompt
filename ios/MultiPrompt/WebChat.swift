import UIKit
import WebKit

struct WebCfg {
    let id: String
    let name: String
    let homeUrl: String
    let startUrl: String
    let composer: [String]
    let send: [String]
    let reply: [String]
}

enum WebChat {

    static let platforms: [WebCfg] = [
        WebCfg(
            id: "chatgpt", name: "ChatGPT",
            homeUrl: "https://chatgpt.com/", startUrl: "https://chatgpt.com/c/",
            composer: ["#prompt-textarea", "div[contenteditable=\"true\"][role=\"textbox\"]", "textarea#chat-input"],
            send: ["button[aria-label=\"Send message\"]", "button[aria-label=\"Kirim pesan\"]"],
            reply: ["div[data-message-author-role=\"assistant\"] .markdown", "div[data-message-id] .markdown"]
        ),
        WebCfg(
            id: "claude", name: "Claude",
            homeUrl: "https://claude.ai/login", startUrl: "https://claude.ai/new",
            composer: ["div[role=\"textbox\"][contenteditable=\"true\"]", "div[contenteditable=\"true\"]"],
            send: ["button[aria-label=\"Send message\"]", "button[data-testid=\"send-button\"]"],
            reply: ["div[data-testid=\"assistant-message-text\"]", ".font-claude-message", "article .message-content"]
        ),
        WebCfg(
            id: "gemini", name: "Google Gemini",
            homeUrl: "https://gemini.google.com/", startUrl: "https://gemini.google.com/app",
            composer: ["rich-textarea .ql-editor", "div.ql-editor[contenteditable=\"true\"]"],
            send: ["button.send-button", "button[aria-label=\"kirim pesan\"]"],
            reply: ["message-content .ql-editor", "message-content", ".model-response-text"]
        ),
        WebCfg(
            id: "copilot", name: "Microsoft Copilot",
            homeUrl: "https://copilot.microsoft.com/", startUrl: "https://copilot.microsoft.com/",
            composer: ["#searchbox", "div[role=\"textbox\"][contenteditable=\"true\"]", "div.ql-editor"],
            send: ["button[aria-label=\"Send\"]", "button[data-testid=\"sendButton\"]"],
            reply: [".turn[data-role=\"assistant\"]", ".markdown-content"]
        ),
        WebCfg(
            id: "grok", name: "Grok",
            homeUrl: "https://grok.com/", startUrl: "https://grok.com/",
            composer: ["textarea[placeholder]", "div[contenteditable=\"true\"][role=\"textbox\"]", "div.ql-editor"],
            send: ["button[type=\"submit\"]", "button[aria-label*=\"Send\"]"],
            reply: ["div[class*=\"prose\"]", ".markdown"]
        ),
        WebCfg(
            id: "deepseek", name: "DeepSeek",
            homeUrl: "https://chat.deepseek.com/", startUrl: "https://chat.deepseek.com/",
            composer: ["textarea", "div[contenteditable=\"true\"]"],
            send: ["button[aria-label=\"Send\"]"],
            reply: [".ds-markdown", "div[class*=\"message-content\"]"]
        )
    ]

    static func byId(_ id: String) -> WebCfg? { platforms.first { $0.id == id } }

    static var active: [String: Session] = [:]

    static func run(_ cfg: WebCfg, prompt: String, in vc: UIViewController,
                    completion: @escaping (String?, String?) -> Void) {
        let s = Session(cfg: cfg, prompt: prompt, completion: completion)
        active[cfg.id] = s
        s.start(in: vc)
    }

    // MARK: - Sesi otomasi

    class Session: NSObject, WKNavigationDelegate {
        let cfg: WebCfg
        let prompt: String
        let completion: (String?, String?) -> Void
        var webView: WKWebView!
        var loaded = false
        var finished = false
        var last = ""
        var stable = 0
        var deadline = Date().addingTimeInterval(180)

        init(cfg: WebCfg, prompt: String, completion: @escaping (String?, String?) -> Void) {
            self.cfg = cfg
            self.prompt = prompt
            self.completion = completion
        }

        func start(in vc: UIViewController) {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()
            let wv = WKWebView(frame: CGRect(x: 20000, y: 0, width: 1100, height: 1600), configuration: config)
            wv.navigationDelegate = self
            wv.customUserAgent = Providers.userAgent
            vc.view.addSubview(wv)
            webView = wv
            wv.load(URLRequest(url: URL(string: cfg.startUrl)!))
        }

        func finish(_ text: String?, _ err: String?) {
            guard !finished else { return }
            finished = true
            WebChat.active[cfg.id] = nil
            webView?.removeFromSuperview()
            completion(text, err)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !loaded else { return }
            loaded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.typeAndSend() }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finish(nil, "\(cfg.name): gagal memuat halaman (\(error.localizedDescription))")
        }

        private func jsArray(_ items: [String]) -> String {
            return Providers.jsonStringTry(items)
        }

        func typeAndSend() {
            let quote = Providers.jsonStringTry([prompt]).dropFirst().dropLast() // string JSON termask kutip
            let js = """
            (function(){
              var sels = \(jsArray(cfg.composer));
              var el = null;
              for (var i=0;i<sels.length;i++){ try{ el=document.querySelector(sels[i]); }catch(e){ el=null; } if(el) break; }
              if(!el) return 'NO_COMPOSER';
              window.__mp_el = el;
              try{ el.scrollIntoView(); el.click(); el.focus(); }catch(e){}
              var text = \(quote);
              if(el.isContentEditable){
                var okInsert=false;
                try{ okInsert=document.execCommand('insertText',false,text); }catch(e){}
                if(!okInsert || (el.textContent||'').trim().length===0){
                  el.textContent = text;
                  try{ el.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText'})); }catch(e){}
                }
              } else {
                var proto = el.tagName==='TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
                var setter = Object.getOwnPropertyDescriptor(proto,'value').set;
                setter.call(el, text);
                try{ el.dispatchEvent(new Event('input',{bubbles:true})); }catch(e){}
              }
              return 'OK';
            })()
            """
            webView.evaluateJavaScript(js) { [weak self] res, err in
                guard let s = self, !s.finished else { return }
                let v = (res as? String) ?? ""
                if err != nil || !v.contains("OK") {
                    s.finish(nil, "\(s.cfg.name): kolom input tidak ditemukan — tekan Login, masuk ke akun Anda, tutup, lalu Kirim lagi.")
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let s2 = self, !s2.finished else { return }
                    let sendJs = """
                    (function(){
                      var el = window.__mp_el; if(!el) return 'NO_EL';
                      var opts = {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true};
                      try{
                        el.dispatchEvent(new KeyboardEvent('keydown',opts));
                        el.dispatchEvent(new KeyboardEvent('keypress',opts));
                        el.dispatchEvent(new KeyboardEvent('keyup',opts));
                      }catch(e){}
                      var sends = \(s2.jsArray(s2.cfg.send));
                      for(var i=0;i<sends.length;i++){ try{ var b=document.querySelector(sends[i]); if(b){ b.click(); break; } }catch(e){} }
                      return 'SENT';
                    })()
                    """
                    s2.webView.evaluateJavaScript(sendJs) { _, _ in s2.startPolling() }
                }
            }
        }

        func startPolling() {
            guard !finished else { return }
            let replyJs = """
            (function(){
              var sels = \(jsArray(cfg.reply));
              for(var i=0;i<sels.length;i++){
                try{
                  var ns=document.querySelectorAll(sels[i]);
                  if(ns.length){ var t=ns[ns.length-1].innerText||''; if(t.trim()) return t; }
                }catch(e){}
              }
              return '';
            })()
            """
            webView.evaluateJavaScript(replyJs) { [weak self] res, _ in
                guard let s = self, !s.finished else { return }
                let txt = ((res as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !txt.isEmpty && txt == s.last {
                    s.stable += 1
                    if s.stable >= 3 { s.finish(txt, nil); return }
                } else {
                    s.stable = 0
                    s.last = txt
                }
                if Date() > s.deadline {
                    if s.last.isEmpty { s.finish(nil, "\(s.cfg.name): tidak ada respons dalam 3 menit.") }
                    else { s.finish(s.last, nil) }
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { s.startPolling() }
            }
        }
    }
}

// MARK: - Layar login manual

class LoginWebViewController: UIViewController {

    let cfg: WebCfg
    private var webView: WKWebView!

    init(cfg: WebCfg) {
        self.cfg = cfg
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Login \(cfg.name)"
        view.backgroundColor = UIColor(red: 0.062, green: 0.078, blue: 0.094, alpha: 1)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Selesai", style: .done, target: self, action: #selector(tutup))

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = Providers.userAgent
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        webView.load(URLRequest(url: URL(string: cfg.homeUrl)!))
    }

    @objc private func tutup() {
        navigationController?.popViewController(animated: true)
    }
}
