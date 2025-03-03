import UIKit

class KeyboardViewController: UIInputViewController {
    
    // 定義鍵盤行數和每行按鍵數
    let keyboardRows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "delete"],
        ["shift", "z", "x", "c", "v", "b", "n", "m", "return"],
        ["mode", "space", "mode", "dismiss"]
    ]
    
    // 對應的嘸蝦米字根
    let boshiamySymbols = [
        ["1↑", "2↑", "3↑", "4↑", "5↑", "6↑", "7↑", "8↑", "9↑", "0↑"],
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L", "⌫"],
        ["⇧", "Z", "X", "C", "V", "B", "N", "M", "⏎"],
        ["123", "  　", "中/英", "⌄"]
    ]
    
    // 視圖和按鍵
    var keyboardView: UIView!
    var candidateView: UIScrollView!
    var keyButtons = [[UIButton]]()
    var candidateButtons = [UIButton]()
    
    // 狀態變數
    var isShifted = false
    var collectedRoots = ""
    var boshiamyDictionary: [String: [String]] = [:]
    
    // 約束參考
    var candidateViewHeightConstraint: NSLayoutConstraint!
    
    // 生命週期方法
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad")
        
        // 加載字典
        loadBoshiamyDictionary()
        
        // 設置視圖
        setupViews()
    }
    
    // 使用Auto Layout設置視圖
    private func setupViews() {
        // 創建候選字視圖
        candidateView = UIScrollView()
        candidateView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        candidateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(candidateView)
        
        // 創建鍵盤視圖
        keyboardView = UIView()
        keyboardView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        
        // 設置約束
        NSLayoutConstraint.activate([
            // 候選字視圖約束
            candidateView.topAnchor.constraint(equalTo: view.topAnchor),
            candidateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // 鍵盤視圖約束
            keyboardView.topAnchor.constraint(equalTo: candidateView.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 保存高度約束以便後續更改
        candidateViewHeightConstraint = candidateView.heightAnchor.constraint(equalToConstant: 40)
        candidateViewHeightConstraint.isActive = true
        
        // 初始化空的候選字視圖
        displayCandidates([])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("viewDidLayoutSubviews: \(view.bounds)")
        
        // 只有在需要時才創建按鍵
        if keyButtons.isEmpty {
            createKeyButtons()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        print("viewWillTransition: 將轉換到尺寸 \(size)")
        
        // 在轉場完成後重新創建按鍵
        coordinator.animate(alongsideTransition: nil) { _ in
            // 清除現有按鍵
            for subview in self.keyboardView.subviews {
                subview.removeFromSuperview()
            }
            self.keyButtons.removeAll()
            
            // 重新創建按鍵
            DispatchQueue.main.async {
                self.createKeyButtons()
            }
        }
    }
    
    // 使用Auto Layout創建按鍵
    private func createKeyButtons() {
        print("創建按鍵")
        
        // 檢查方向
        let isLandscape = view.bounds.width > view.bounds.height
        
        // 清除現有按鍵
        for subview in keyboardView.subviews {
            subview.removeFromSuperview()
        }
        keyButtons.removeAll()
        
        // 創建容器堆疊視圖
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fillEqually
        mainStackView.spacing = isLandscape ? 4 : 6
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(mainStackView)
        
        // 設置堆疊視圖約束，添加邊距
        let padding: CGFloat = 8
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: padding),
            mainStackView.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: padding),
            mainStackView.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -padding),
            mainStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -padding)
        ])
        
        // 逐行創建按鍵
        for (rowIndex, rowKeys) in keyboardRows.enumerated() {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.distribution = .fillProportionally
            rowStackView.spacing = isLandscape ? 4 : 6
            rowStackView.translatesAutoresizingMaskIntoConstraints = false
            
            var rowButtons = [UIButton]()
            
            for (keyIndex, keyTitle) in rowKeys.enumerated() {
                // 創建按鈕
                let button = UIButton(type: .system)
                button.backgroundColor = UIColor.white
                button.setTitleColor(UIColor.black, for: .normal)
                button.layer.cornerRadius = 5
                button.layer.borderWidth = 0.5
                button.layer.borderColor = UIColor.darkGray.cgColor
                button.setTitle(keyTitle, for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: isLandscape ? 16 : 18)
                button.tag = rowIndex * 100 + keyIndex
                button.addTarget(self, action: #selector(keyPressed(_:)), for: .touchUpInside)
                button.translatesAutoresizingMaskIntoConstraints = false
                
                // 設置按鈕寬度權重
                if keyTitle == "space" {
                    button.setContentHuggingPriority(.defaultLow - 100, for: .horizontal)
                    button.setContentCompressionResistancePriority(.defaultLow - 100, for: .horizontal)
                } else if keyTitle == "delete" || keyTitle == "return" {
                    button.setContentHuggingPriority(.defaultLow - 50, for: .horizontal)
                    button.setContentCompressionResistancePriority(.defaultLow - 50, for: .horizontal)
                } else {
                    button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                    button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
                }
                
                // 添加到堆疊視圖和數組
                rowStackView.addArrangedSubview(button)
                rowButtons.append(button)
            }
            
            // 添加這一行到主堆疊視圖
            mainStackView.addArrangedSubview(rowStackView)
            keyButtons.append(rowButtons)
        }
    }
    
    // 按鍵處理方法
    @objc func keyPressed(_ sender: UIButton) {
        // 取得按下的按鍵
        let row = sender.tag / 100
        let col = sender.tag % 100
        
        if row < keyboardRows.count && col < keyboardRows[row].count {
            let key = keyboardRows[row][col]
            
            // 播放按鍵反饋
            animateButton(sender)
            
            // 處理特殊按鍵
            switch key {
            case "delete":
                textDocumentProxy.deleteBackward()
            case "return":
                textDocumentProxy.insertText("\n")
            case "space":
                textDocumentProxy.insertText(" ")
            case "shift":
                toggleShift()
            case "mode":
                toggleInputMode()
            case "dismiss":
                dismissKeyboard()
            default:
                // 一般按鍵，進行嘸蝦米輸入處理
                handleBoshiamyInput(key)
            }
        }
    }
    
    // 切換大小寫
    func toggleShift() {
        isShifted = !isShifted
        
        // 更新按鍵顯示
        for (rowIndex, rowButtons) in keyButtons.enumerated() {
            for (keyIndex, button) in rowButtons.enumerated() {
                if rowIndex == 1 || rowIndex == 2 || (rowIndex == 3 && keyIndex > 0 && keyIndex < keyButtons[3].count - 1) {
                    if rowIndex < keyboardRows.count && keyIndex < keyboardRows[rowIndex].count {
                        let key = keyboardRows[rowIndex][keyIndex]
                        if key.count == 1 && key >= "a" && key <= "z" {
                            let newKey = isShifted ? key.uppercased() : key
                            button.setTitle(newKey, for: .normal)
                        }
                    }
                }
            }
        }
    }
    
    // 切換輸入模式
    func toggleInputMode() {
        // 實現中英文切換邏輯
        print("切換輸入模式")
    }
    
    // 關閉鍵盤方法
    override func dismissKeyboard() {
        advanceToNextInputMode()
    }
    
    // 處理嘸蝦米輸入邏輯
    func handleBoshiamyInput(_ key: String) {
        // 收集字根
        collectedRoots += key
        
        // 查詢嘸蝦米字典，獲取候選字
        let candidates = lookupBoshiamyDictionary(collectedRoots)
        
        // 顯示候選字詞
        displayCandidates(candidates)
    }
    
    // 嘸蝦米字典查詢
    func lookupBoshiamyDictionary(_ roots: String) -> [String] {
        // 這裡應連接到您的嘸蝦米字典資料
        // 返回符合字根組合的候選字列表
        
        // 示例（您需要替換為實際的字典查詢）
        return ["字1", "字2", "字3"]
    }
    
    // 使用Auto Layout顯示候選字詞
    func displayCandidates(_ candidates: [String]) {
        // 清除現有的候選字按鈕
        for button in candidateButtons {
            button.removeFromSuperview()
        }
        candidateButtons.removeAll()
        
        // 如果沒有候選字，縮小候選字視圖高度
        if candidates.isEmpty {
            candidateViewHeightConstraint.constant = 40
            view.layoutIfNeeded()
            return
        }
        
        // 有候選字時，適當調整高度
        candidateViewHeightConstraint.constant = 40
        view.layoutIfNeeded()
        
        // 創建堆疊視圖容器
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 5
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        candidateView.addSubview(stackView)
        
        // 設置堆疊視圖約束
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: candidateView.topAnchor, constant: 5),
            stackView.leadingAnchor.constraint(equalTo: candidateView.leadingAnchor, constant: 5),
            stackView.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // 創建候選字按鈕
        for (index, candidate) in candidates.enumerated() {
            let button = UIButton(type: .system)
            button.backgroundColor = UIColor.white
            button.layer.cornerRadius = 4
            button.setTitle(candidate, for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(candidateSelected(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            
            // 設置按鈕尺寸約束
            let buttonWidth = max(40, candidate.count * 30)
            button.widthAnchor.constraint(equalToConstant: CGFloat(buttonWidth)).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            
            // 添加到堆疊視圖和數組
            stackView.addArrangedSubview(button)
            candidateButtons.append(button)
        }
        
        // 更新候選區域內容大小
        candidateView.contentSize = CGSize(width: stackView.frame.width + 10, height: 40)
    }
    
    // 候選字被選中
    @objc func candidateSelected(_ sender: UIButton) {
        let candidate = sender.title(for: .normal) ?? ""
        
        // 輸入選中的字詞
        textDocumentProxy.insertText(candidate)
        
        // 清除已輸入的字根
        collectedRoots = ""
        
        // 清空候選字區域
        displayCandidates([])
    }
    
    // 加載字典資料
    func loadBoshiamyDictionary() {
        // 從資源文件加載字典
        if let path = Bundle.main.path(forResource: "boshiamy", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                boshiamyDictionary = try JSONDecoder().decode([String: [String]].self, from: data)
            } catch {
                print("無法加載嘸蝦米字典: \(error)")
            }
        }
    }
    
    // 添加按鍵視覺反饋
    func animateButton(_ button: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            button.backgroundColor = UIColor.lightGray
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.backgroundColor = UIColor.white
            }
        }
    }
}
