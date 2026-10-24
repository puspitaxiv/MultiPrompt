import Foundation

struct Provider {
    let id: String
    let name: String
    let web: Bool // true = login manual via WKWebView
}

enum Providers {

    static let all: [Provider] = [
        Provider(id: "chatgpt", name: "ChatGPT (login sendiri)", web: true),
        Provider(id: "claude", name: "Claude (login sendiri)", web: true),
        Provider(id: "gemini", name: "Google Gemini (login sendiri)", web: true),
        Provider(id: "copilot", name: "Microsoft Copilot (login sendiri)", web: true),
        Provider(id: "grok", name: "Grok (login sendiri)", web: true),
        Provider(id: "deepseek", name: "DeepSeek (login sendiri)", web: true),
        Provider(id: "ddg-gpt", name: "DuckDuckGo · GPT-4o mini", web: false),
        Provider(id: "ddg-claude", name: "DuckDuckGo · Claude Sonnet", web: false),
        Provider(id: "ddg-llama", name: "DuckDuckGo · Llama 3.1 70B", web: false),
        Provider(id: "ddg-qwen", name: "DuckDuckGo · Qwen 2.5 72B", web: false),
        Provider(id: "pollination", name: "Pollinations (gratis)", web: false)
    ]

    static let ddgModels: [String: String] = [
        "ddg-gpt": "gpt-4o-mini",
        "ddg-claude": "claude-sonnet-4",
        "ddg-llama": "meta-llama/Meta-Llama-3.1-70B-Instruct",
        "ddg-qwen": "qwen/qwen-2.5-72b-instruct"
    ]

    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    /// Hanya untuk penyedia HTTP (bukan web:true). completion di thread utama.
    static func ask(_ id: String, _ prompt: String, _ completion: @escaping (String?, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var text: String?
            var err: String?
            do {
                if let model = ddgModels[id] {
                    text = try duckDuckGo(model: model, prompt: prompt)
                } else if id == "pollination" {
                    text = try pollinations(prompt: prompt)
                } else {
                    throw error("Provider tidak dikenal: \(id)")
                }
            } catch let e {
                err = e.localizedDescription
            }
            DispatchQueue.main.async { completion(text, err) }
        }
    }

    static func error(_ msg: String) -> NSError {
        return NSError(domain: "MultiPrompt", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }

    // MARK: - HTTP dasar

    private static func send(_ method: String, _ urlStr: String, _ headers: [String: String],
                             _ body: Data?, timeout: TimeInterval = 120) throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: urlStr) else { throw error("URL tidak valid") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = timeout
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = body

        var outData: Data?
        var outResp: URLResponse?
        var outErr: Error?
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { d, r, e in
            outData = d; outResp = r; outErr = e; sem.signal()
        }.resume()
        sem.wait()
        if let e = outErr { throw error("Jaringan: \(e.localizedDescription)") }
        guard let http = outResp as? HTTPURLResponse else { throw error("Respons bukan HTTP") }
        if !(200...299 ~= http.statusCode) {
            let txt = String(data: outData ?? Data(), encoding: .utf8) ?? ""
            throw error("HTTP \(http.statusCode): \(String(txt.prefix(200)))")
        }
        return (outData ?? Data(), http)
    }

    static func jsonStringTry(_ obj: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    private static func json(_ data: Data) throws -> Any {
        return try JSONSerialization.jsonObject(with: data)
    }

    // MARK: - DuckDuckGo (tanpa akun, tidak resmi)

    private static func duckDuckGo(model: String, prompt: String) throws -> String {
        let (modelsData, _) = try send("GET", "https://duck.ai/models", ["Accept": "application/json"], nil, timeout: 30)
        let modelsTxt = String(data: modelsData, encoding: .utf8) ?? ""
        guard let vqd = firstMatch(modelsTxt, pattern: "vqd=([0-9a-zA-Z_-]+)") else {
            throw error("Gagal ambil token DuckDuckGo (layanan berubah/diblokir)")
        }
        let uuid = UUID().uuidString.lowercased()
        let body: [String: Any] = [
            "searchParams": ["qd": prompt, "vqd": vqd],
            "messages": [["action_type": "next", "content": prompt, "context": [String: Any](),
                          "role": "user", "id": uuid] as [String: Any]],
            "tools": [Any](),
            "title": String(prompt.prefix(48)),
            "model": model,
            "chatSessionId": randomString(52),
            "deepSearch": false,
            "isGenerated": false,
            "parentMessageId": uuid,
            "temperature": 0.7,
            "topP": 0.9
        ]
        let payload = "body=" + jsonStringTry(body)
        let (chatData, _) = try send("POST", "https://duck.ai/chat/?chat_version=2",
                                     ["Content-Type": "application/x-www-form-urlencoded",
                                      "Accept": "text/event-stream",
                                      "x-vqd-4": uuid,
                                      "Origin": "https://duck.ai"],
                                     payload.data(using: .utf8))
        let raw = String(data: chatData, encoding: .utf8) ?? ""
        var answer = ""
        for line in raw.split(separator: "\n") {
            let l = String(line).trimmingCharacters(in: .whitespaces)
            guard l.hasPrefix("data:") else { continue }
            let payloadStr = String(l.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if payloadStr.isEmpty || payloadStr == "[DONE]" { continue }
            guard let d = payloadStr.data(using: .utf8),
                  let o = try? json(d) as? [String: Any],
                  (o["role"] as? String) == "assistant",
                  let c = o["content"] as? String else { continue }
            answer += c
        }
        let out = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if out.isEmpty { throw error("DuckDuckGo tidak mengirim jawaban") }
        return out
    }

    private static func firstMatch(_ text: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func randomString(_ n: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<n).map { _ in chars.randomElement()! })
    }

    // MARK: - Pollinations

    private static func pollinations(prompt: String) throws -> String {
        let enc = prompt.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? prompt
        let (d, _) = try send("GET", "https://text.pollinations.ai/\(enc)?model=openai&nolog=true", [:], nil)
        let txt = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if txt.isEmpty { throw error("Pollinations mengirim balasan kosong") }
        return txt
    }
}
