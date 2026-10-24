import UIKit

class ViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let promptView = UITextView()
    private let placeholder = UILabel()
    private var switches = [(String, UISwitch)]()
    private let resultsStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MultiPrompt"
        view.backgroundColor = UIColor(red: 0.062, green: 0.078, blue: 0.094, alpha: 1)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Kunci", style: .plain, target: self, action: #selector(openKeys))

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor)
        ])

        stack.axis = .vertical
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        let info = UILabel()
        info.text = "Satu prompt, dikirim serentak ke beberapa AI. Tanpa PC."
        info.font = info.font.withSize(13)
        info.textColor = UIColor.lightGray
        info.numberOfLines = 0
        stack.addArrangedSubview(info)

        promptView.backgroundColor = UIColor(red: 0.094, green: 0.122, blue: 0.149, alpha: 1)
        promptView.textColor = .white
        promptView.font = UIFont.systemFont(ofSize: 16)
        promptView.isScrollEnabled = false
        promptView.delegate = self
        promptView.layer.cornerRadius = 6
        promptView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        stack.addArrangedSubview(promptView)
        promptView.heightAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true

        placeholder.text = "Tulis prompt di sini…"
        placeholder.textColor = UIColor.lightGray
        placeholder.font = UIFont.systemFont(ofSize: 16)
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        promptView.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.topAnchor.constraint(equalTo: promptView.topAnchor, constant: 12),
            placeholder.leadingAnchor.constraint(equalTo: promptView.leadingAnchor, constant: 12)
        ])

        let pickLabel = UILabel()
        pickLabel.text = "Pilih AI tujuan:"
        pickLabel.font = UIFont.boldSystemFont(ofSize: 14)
        pickLabel.textColor = .white
        stack.addArrangedSubview(pickLabel)

        for p in Providers.all {
            let row = UIView()
            let lab = UILabel()
            lab.text = p.name
            lab.font = UIFont.systemFont(ofSize: 15)
            lab.textColor = .white
            lab.numberOfLines = 0
            let sw = UISwitch()
            sw.isOn = defaultOn(p.id)
            sw.addTarget(self, action: #selector(saveChoice(_:)), for: .valueChanged)
            sw.accessibilityIdentifier = p.id
            row.addSubview(lab)
            row.addSubview(sw)
            lab.translatesAutoresizingMaskIntoConstraints = false
            sw.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                lab.topAnchor.constraint(equalTo: row.topAnchor, constant: 6),
                lab.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -6),
                lab.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                sw.leadingAnchor.constraint(greaterThanOrEqualTo: lab.trailingAnchor, constant: 8),
                sw.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                sw.centerYAnchor.constraint(equalTo: lab.centerYAnchor),
                lab.trailingAnchor.constraint(lessThanOrEqualTo: sw.leadingAnchor, constant: -8)
            ])
            switches.append((p.id, sw))
            stack.addArrangedSubview(row)
        }

        let runBtn = UIButton(type: .system)
        runBtn.setTitle("Kirim ke Semua", for: .normal)
        runBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        runBtn.setTitleColor(.white, for: .normal)
        runBtn.backgroundColor = UIColor(red: 0.184, green: 0.506, blue: 0.969, alpha: 1)
        runBtn.layer.cornerRadius = 8
        runBtn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        runBtn.addTarget(self, action: #selector(kirim), for: .touchUpInside)
        stack.addArrangedSubview(runBtn)

        resultsStack.axis = .vertical
        resultsStack.spacing = 8
        stack.addArrangedSubview(resultsStack)
    }

    private func defaultOn(_ id: String) -> Bool {
        let key = "pick_\(id)"
        if UserDefaults.standard.object(forKey: key) != nil {
            return UserDefaults.standard.bool(forKey: key)
        }
        return id.hasPrefix("ddg") || id == "pollination"
    }

    @objc private func saveChoice(_ sender: UISwitch) {
        if let id = sender.accessibilityIdentifier {
            UserDefaults.standard.set(sender.isOn, forKey: "pick_\(id)")
        }
    }

    @objc private func openKeys() {
        navigationController?.pushViewController(KeysViewController(), animated: true)
    }

    @objc private func kirim() {
        view.endEditing(true)
        let prompt = promptView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if prompt.isEmpty {
            placeholder.isHidden = false
            return
        }
        resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (id, sw) in switches where sw.isOn {
            guard let provider = Providers.all.first(where: { $0.id == id }) else { continue }
            let head = UILabel()
            head.text = "\(provider.name) — mengirim…"
            head.font = UIFont.boldSystemFont(ofSize: 14)
            head.textColor = UIColor.lightGray
            head.numberOfLines = 0
            let body = UILabel()
            body.font = UIFont.systemFont(ofSize: 15)
            body.textColor = .white
            body.numberOfLines = 0
            resultsStack.addArrangedSubview(head)
            resultsStack.addArrangedSubview(body)

            Providers.ask(id, prompt) { text, err in
                if let e = err {
                    head.text = "\(provider.name) — GAGAL"
                    body.text = e
                } else {
                    head.text = "\(provider.name) — selesai"
                    body.text = text
                }
            }
        }
    }
}

extension ViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
    }
}

class KeysViewController: UIViewController {

    private let fields: [(String, String)] = [
        ("OpenAI API key", "openai_key"),
        ("Google Gemini API key", "gemini_key"),
        ("OpenRouter API key", "openrouter_key"),
        ("OpenRouter model (kosong = llama free)", "openrouter_model")
    ]
    private var textFields = [String: UITextField]()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "API Keys"
        view.backgroundColor = UIColor(red: 0.062, green: 0.078, blue: 0.094, alpha: 1)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])

        let info = UILabel()
        info.text = "Isi key bila punya. DuckDuckGo & Pollinations tidak butuh key."
        info.font = info.font.withSize(13)
        info.textColor = UIColor.lightGray
        info.numberOfLines = 0
        stack.addArrangedSubview(info)

        for (label, key) in fields {
            let lab = UILabel()
            lab.text = label
            lab.font = UIFont.systemFont(ofSize: 14)
            lab.textColor = .white
            let tf = UITextField()
            tf.text = Prefs.key(key)
            tf.placeholder = "kosongkan jika tidak dipakai"
            tf.backgroundColor = UIColor(red: 0.094, green: 0.122, blue: 0.149, alpha: 1)
            tf.textColor = .white
            tf.font = UIFont.systemFont(ofSize: 15)
            tf.borderStyle = .roundedRect
            tf.autocorrectionType = .no
            tf.heightAnchor.constraint(equalToConstant: 40).isActive = true
            textFields[key] = tf
            stack.addArrangedSubview(lab)
            stack.addArrangedSubview(tf)
        }

        let save = UIButton(type: .system)
        save.setTitle("Simpan", for: .normal)
        save.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        save.backgroundColor = UIColor(red: 0.184, green: 0.506, blue: 0.969, alpha: 1)
        save.layer.cornerRadius = 8
        save.heightAnchor.constraint(equalToConstant: 44).isActive = true
        save.addTarget(self, action: #selector(simpan), for: .touchUpInside)
        stack.addArrangedSubview(save)
    }

    @objc private func simpan() {
        for (key, tf) in textFields {
            Prefs.setKey(key, tf.text ?? "")
        }
        navigationController?.popViewController(animated: true)
    }
}
