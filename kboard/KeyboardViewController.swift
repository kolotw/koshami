import UIKit
import FMDB

class KeyboardViewController: UIInputViewController {
    
    var database: FMDatabase?
    var isIPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    // 定義鍵盤行數和每行按鍵數
    let keyboardRows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "'"],
        ["⇧", "z", "x", "c", "v", "b", "n", "m", ",", "."],
        ["🌐", "  space  ", "中"]
    ]
    let secondaryLabels = [
        ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"],
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L", ""],
        ["", "Z", "X", "C", "V", "B", "N", "M", "", ""],
        ["", "", ""]
    ]
    
    // 對應的嘸蝦米字根
    let boshiamySymbols = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L", "、"],
        ["Z", "X", "C", "V", "B", "N", "M", "，", "."],
        ["🌐", "   space   ", "英"]
    ]
    let boshiamySecondaryLabels = [
        ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "'"],
        ["z", "x", "c", "v", "b", "n", "m", "<", ">"],
        ["", "", "", ""]
    ]
    
    // 視圖和按鍵
    var keyboardView: UIView!
    var candidateView: UIScrollView!
    var keyButtons = [[UIButton]]()
    var candidateButtons = [UIButton]()
    
    // 狀態變數
    var isShifted = false
    var isShiftLocked = false  // 用於區分臨時大寫和鎖定大寫
    var collectedRoots = ""
    var inMemoryBoshiamyDict: [String: [String]] = [:]
    
    // 約束參考
    var candidateViewHeightConstraint: NSLayoutConstraint!
    
    var isBoshiamyMode = true  // true 為嘸蝦米模式，false 為英文模式
    // 添加一個狀態變量來追踪是否在"小字模式"
    var isSecondaryLabelMode = false
    var inputCodeLabel: UILabel!
    var titleFontSize: CGFloat = 8
    var subtitleFontSize: CGFloat = 10
    
    var isAsyncInitialized = false
    // 在類中添加這些變數來保存初始的尺寸資訊
    private var initialKeyboardWidth: CGFloat = 0
    private var initialKeyboardHeight: CGFloat = 0
    private var initialIsLandscape: Bool = false
    private var initialKeyboardMetricsSet = false
    
    // 同音字反查功能所需的屬性
    var isHomophoneLookupMode = false  // 表示是否處於同音字反查模式
    var homophoneLookupStage = 0       // 反查階段: 0=未開始, 1=輸入字根, 2=選擇注音, 3=選擇同音字
    var lastSelectedCharacter = ""     // 最後選擇的字
    var bopomofoDictionary: [String: [String]] = [:]  // 字 -> 注音列表
    var bopomospellDictionary: [String: [String]] = [:]  // 注音 -> 字列表
    
    private var deleteTimer: Timer?
    private var isLongPressDeleteActive = false
    
    // 初始化資料庫
    func initDatabase() {
        // 找到 Bundle 中的資料庫
        guard let bundleDBPath = Bundle.main.path(forResource: "liu", ofType: "db") else {
            print("在 Bundle 中找不到資料庫檔案")
            return
        }
        
        // 獲取臨時目錄路徑
        let tempDirectory = NSTemporaryDirectory()
        let destinationPath = tempDirectory + "liu.db"
        
        do {
            // 如果檔案已存在，先移除
            if FileManager.default.fileExists(atPath: destinationPath) {
                try FileManager.default.removeItem(atPath: destinationPath)
            }
            
            // 複製資料庫到臨時目錄
            try FileManager.default.copyItem(atPath: bundleDBPath, toPath: destinationPath)
            print("資料庫已複製到: \(destinationPath)")
            
            // 打開複製的資料庫
            database = FMDatabase(path: destinationPath)
            if database?.open() == true {
                print("成功開啟資料庫，路徑: \(destinationPath)")
                
                // 禁用 WAL 模式
                if database?.executeUpdate("PRAGMA journal_mode=DELETE", withArgumentsIn: []) == true {
                    print("已設定標準 journal 模式")
                }
            } else {
                print("開啟資料庫失敗: \(database?.lastErrorMessage() ?? "未知錯誤")")
            }
        } catch {
            print("處理資料庫失敗: \(error)")
        }
    }
    
    // 根據裝置類型獲取適當的字型大小
    func getFontSize(baseLandscapeSize: CGFloat, basePortraitSize: CGFloat) -> CGFloat {
        let isLandscape = view.bounds.width > view.bounds.height
        
        if isIPhone {
            // iPhone 上的字型大小縮小，直式模式下更小
            if isLandscape {
                return baseLandscapeSize - 2 // 橫式模式稍微縮小
            } else {
                return basePortraitSize - 10 // 直式模式更小
            }
        } else {
            // 非 iPhone 設備保持原始大小
            return isLandscape ? baseLandscapeSize : basePortraitSize
        }
    }
    
    private func updateFontAndButtonSizes() {
        let isLandscape = view.bounds.width > view.bounds.height
        let isIPhonePortrait = isIPhone && !isLandscape
        
        if isIPhonePortrait {
            // iPhone 直式模式下的優化設定
            titleFontSize = 8   // 更小的次要標籤字型
            subtitleFontSize = 10 // 更小的主要標籤字型
        } else if isLandscape {
            // 橫向模式設定
            titleFontSize = 10
            subtitleFontSize = 16
        } else {
            // 其他情況（iPad等）
            titleFontSize = 12
            subtitleFontSize = 18
        }
        
        print("更新字型大小設定: titleFontSize = \(titleFontSize), subtitleFontSize = \(subtitleFontSize)")
    }
    
    // 生命週期方法
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("viewDidLoad 開始執行")
        
        // 初始化資料庫
        initDatabase()
        
        // 加載注音資料庫
        loadBopomofoData()
        
        do {
            // 延遲設置視圖，確保尺寸已穩定
            DispatchQueue.main.async {
                self.updateFontAndButtonSizes()
                self.setupViews()
                self.isBoshiamyMode = true  // 預設使用嘸蝦米模式
                
                // 在鍵盤初始化完成後設置長按手勢
                DispatchQueue.main.async {
                    self.setupLongPressGestures()
                }
            }
        }
    }
    
    // 設置長按手勢
    private func setupLongPressGestures() {
        print("設置長按手勢")
        
        // 清除現有的手勢識別器
        for rowButtons in keyButtons {
            for button in rowButtons {
                button.gestureRecognizers?.forEach { gesture in
                    if gesture is UILongPressGestureRecognizer {
                        button.removeGestureRecognizer(gesture)
                    }
                }
            }
        }
        
        // 重新添加長按手勢
        for rowButtons in keyButtons {
            for button in rowButtons {
                // 獲取按鈕的行列索引
                let row = button.tag / 100
                let col = button.tag % 100
                
                // 選擇當前布局
                let currentLayout = isBoshiamyMode ? boshiamySymbols : keyboardRows
                
                // 確保索引有效
                if row < currentLayout.count && col < currentLayout[row].count {
                    let key = currentLayout[row][col]
                    
                    // 跳過特殊按鍵
                    if key.contains("中") || key.contains("英") || key.contains("space") || key.contains("shift") ||
                        key.contains("⇧") || key.contains("dismiss") || key.contains("⌄") ||
                        key.contains("delete") || key.contains("⌫") || key.contains("return") ||
                        key.contains("⏎") || key.contains("🌐") || key.contains("英/中") {
                        continue
                    }
                    
                    // 添加長按手勢
                    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
                    longPress.minimumPressDuration = 0.3 // 設置較短的長按時間以提高響應速度
                    button.addGestureRecognizer(longPress)
                }
            }
        }
    }
    
    // 處理長按事件
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        // 只在手勢開始時處理一次
        if gesture.state == .began, let button = gesture.view as? UIButton {
            print("長按事件觸發")
            
            // 取得按鈕的行列索引
            let row = button.tag / 100
            let col = button.tag % 100
            
            // 選擇當前布局和次要標籤
            let currentLayout = isBoshiamyMode ? boshiamySymbols : keyboardRows
            let currentSecondaryLabels = isBoshiamyMode ? boshiamySecondaryLabels : secondaryLabels
            
            // 確保索引有效
            if row < currentLayout.count && col < currentLayout[row].count &&
                row < currentSecondaryLabels.count && col < currentSecondaryLabels[row].count {
                
                let secondaryText = currentSecondaryLabels[row][col]
                
                if !secondaryText.isEmpty {
                    if isBoshiamyMode {
                        // 嘸蝦米模式下，直接輸入次要標籤對應的字符
                        textDocumentProxy.insertText(secondaryText)
                    } else {
                        // 英文模式下，如果是字母則輸入大寫
                        let key = currentLayout[row][col]
                        if key.count == 1 && key >= "a" && key <= "z" {
                            textDocumentProxy.insertText(key.uppercased())
                        } else {
                            // 非字母按鍵則輸入次要標籤字符
                            textDocumentProxy.insertText(secondaryText)
                        }
                    }
                    
                    // 提供視覺反饋
                    animateButton(button)
                }
            }
        }
    }
    
    // 使用Auto Layout設置視圖
  
    private func setupViews() {
        // 創建候選字視圖
        candidateView = UIScrollView()
        candidateView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        candidateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(candidateView)
        
        // 創建一個輔助視圖，用於標記輸入框的位置
        let positionMarker = UIView()
        positionMarker.translatesAutoresizingMaskIntoConstraints = false
        positionMarker.backgroundColor = UIColor.clear // 透明不可見
        candidateView.addSubview(positionMarker)
        
        // 創建輸入字碼標籤
        inputCodeLabel = UILabel()
        inputCodeLabel.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        inputCodeLabel.textColor = UIColor.darkGray
        inputCodeLabel.font = UIFont.systemFont(ofSize: 22)
        inputCodeLabel.textAlignment = .center
        inputCodeLabel.translatesAutoresizingMaskIntoConstraints = false
        candidateView.addSubview(inputCodeLabel)
        
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
            
            // 位置標記約束 - 放在左側約1/3處
            positionMarker.topAnchor.constraint(equalTo: candidateView.topAnchor),
            positionMarker.leadingAnchor.constraint(equalTo: candidateView.leadingAnchor),
            positionMarker.widthAnchor.constraint(equalTo: candidateView.widthAnchor, multiplier: 0.33), // 放在1/3處
            positionMarker.heightAnchor.constraint(equalToConstant: 1), // 高度為1，基本不可見
            
            // 輸入字碼標籤約束 - 與位置標記右側對齊
            inputCodeLabel.topAnchor.constraint(equalTo: candidateView.topAnchor, constant: 5),
            inputCodeLabel.leadingAnchor.constraint(equalTo: positionMarker.trailingAnchor),
            inputCodeLabel.heightAnchor.constraint(equalToConstant: 40),
            
            // 鍵盤視圖約束
            keyboardView.topAnchor.constraint(equalTo: candidateView.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 保存高度約束以便後續更改
        candidateViewHeightConstraint = candidateView.heightAnchor.constraint(equalToConstant: 50)
        candidateViewHeightConstraint.isActive = true
        
        // 初始化空的候選字視圖和清空輸入字碼
        updateInputCodeDisplay("")
        displayCandidates([])
    }

    
    private func updateInputCodeDisplay(_ code: String) {
        if code.isEmpty {
            inputCodeLabel.text = ""  // 當沒有輸入時不顯示任何文字
        } else {
            inputCodeLabel.text = "輸入：" + code
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 只有在需要時才創建按鍵，使用延遲確保視圖尺寸已穩定
            if keyButtons.isEmpty {
                // 第一次延遲確保尺寸已穩定
                DispatchQueue.main.async {
                    if self.keyButtons.isEmpty {
                        self.createKeyButtons()
                    }
                }
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
    
    @objc func keyPressed(_ sender: UIButton) {
        // 檢查是否由長按手勢觸發
        if let longPress = sender.gestureRecognizers?.first(where: { $0 is UILongPressGestureRecognizer }) as? UILongPressGestureRecognizer,
           longPress.state == .began || longPress.state == .changed {
            // 已被長按手勢處理，不再重複處理
            return
        }
        
        // 取得按下的按鍵
        let row = sender.tag / 100
        let col = sender.tag % 100
        
        // 選擇當前佈局和次要標籤
        let currentLayout = isBoshiamyMode ? boshiamySymbols : keyboardRows
        
        // 檢查索引是否有效
        guard row < currentLayout.count && col < currentLayout[row].count else {
            print("無效的按鍵索引: row \(row), col \(col)")
            return
        }
        
        let key = currentLayout[row][col]
        
        // 檢查是否為數字鍵，且嘸蝦米模式下已有字根
        if isBoshiamyMode && !collectedRoots.isEmpty && row == 0 && (0...9).contains(col) {
            // 如果嘸蝦米模式下已有字根，忽略數字鍵輸入
            return
        }
        
        // 播放按鍵反饋
        animateButton(sender)
        
        // 檢查是否為「、」符號，觸發同音字反查模式
        if key == "、" && isBoshiamyMode {
            startHomophoneLookup()
            return
        }
        
        // 根據同音字反查階段處理按鍵
        if isHomophoneLookupMode {
            handleHomophoneLookupKeyPress(key)
            return
        }
        
        // 處理特殊按鍵
        if key.contains("中") || key.contains("英") {
            toggleInputMode()
        } else if key.contains("space") || key.contains("  　") {
            // 處理空白鍵
            if isBoshiamyMode && !collectedRoots.isEmpty {
                if !candidateButtons.isEmpty {
                    // 如果有候選字，選擇第一個候選字
                    if let firstCandidateButton = candidateButtons.first {
                        candidateSelected(firstCandidateButton)
                        // candidateSelected 方法會清除 collectedRoots
                    }
                } else {
                    // 如果沒有候選字但有輸入的字根，清除字根
                    collectedRoots = ""
                    updateInputCodeDisplay("")
                    displayCandidates([])
                }
            } else {
                // 普通空白鍵行為
                textDocumentProxy.insertText(" ")
            }
            
            
        } else if key.contains("shift") || key.contains("⇧") {
            toggleShift()
        } else if key.contains("🌐") || key.contains("⌄") {
            dismissKeyboard()
        } else if key.contains("delete") || key.contains("⌫") {
            print("DELETE")
            if isBoshiamyMode && !collectedRoots.isEmpty {
                // 如果在嘸蝦米模式下並且有收集的字根，則刪除最後一個字根
                collectedRoots = String(collectedRoots.dropLast())
                
                // 更新輸入字碼顯示
                updateInputCodeDisplay(collectedRoots)
                
                // 重新查詢候選字
                if collectedRoots.isEmpty {
                    // 如果沒有輸入的字根了，清空候選字區域
                    displayCandidates([])
                } else {
                    // 否則，查詢新的候選字
                    let candidates = lookupBoshiamyDictionary(collectedRoots)
                    displayCandidates(candidates)
                }
            } else {
                // 只有在沒有收集的字根時，才刪除文本
                textDocumentProxy.deleteBackward()
            }
            
            
        } else if key.contains("return") || key.contains("⏎") {
            textDocumentProxy.insertText("\n")
        } else {
            // 一般按鍵，根據模式進行處理
            if isBoshiamyMode {
                // 嘸蝦米模式下的處理
                // 取出嘸蝦米符號（排除空格和數字部分）
                let cleanKey = key.components(separatedBy: " ").first ?? key
                handleBoshiamyInput(cleanKey)
            } else {
                // 英文模式下的處理
                let inputChar = key.first.map(String.init) ?? ""
                let inputText = isShifted && inputChar.count == 1 && (inputChar >= "a" && inputChar <= "z") ?
                inputChar.uppercased() : inputChar
                textDocumentProxy.insertText(inputText)
                
                // 如果是臨時大寫狀態（不是鎖定大寫），則在輸入一個字符後重置
                if isShifted && !isShiftLocked {
                    isShifted = false
                    updateShiftButtonAppearance()
                    updateLetterKeysForShiftState()
                }
            }
        }
    }
    
    // 更新 Shift 按鈕外觀
    func updateShiftButtonAppearance() {
        for (rowIndex, rowButtons) in keyButtons.enumerated() {
            for (keyIndex, button) in rowButtons.enumerated() {
                if rowIndex < keyboardRows.count && keyIndex < keyboardRows[rowIndex].count {
                    let key = keyboardRows[rowIndex][keyIndex]
                    if key.contains("shift") || key.contains("⇧") {
                        if isShifted {
                            if isShiftLocked {
                                // 鎖定大寫
                                button.backgroundColor = UIColor.darkGray
                                button.setTitleColor(UIColor.white, for: .normal)
                            } else {
                                // 臨時大寫
                                button.backgroundColor = UIColor.lightGray
                                button.setTitleColor(UIColor.black, for: .normal)
                            }
                        } else {
                            // 正常狀態
                            button.backgroundColor = UIColor.white
                            button.setTitleColor(UIColor.black, for: .normal)
                        }
                    }
                }
            }
        }
    }
    
    // 根據 Shift 狀態更新字母按鍵顯示
    func updateLetterKeysForShiftState() {
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
    
    // 切換小字模式
    func toggleSecondaryLabelMode() {
        isSecondaryLabelMode = !isSecondaryLabelMode
        
        // 添加視覺反饋以指示當前處於小字模式
        // 例如，可以改變某個指示器的顏色或添加一個標籤
        
        print("切換到\(isSecondaryLabelMode ? "小字" : "正常")模式")
    }
    
    // 切換大小寫
    func toggleShift() {
        if isShifted {
            // 如果當前是 Shift 狀態
            if isShiftLocked {
                // 如果是鎖定狀態，則完全取消 Shift
                isShifted = false
                isShiftLocked = false
            } else {
                // 如果是臨時狀態，則鎖定 Shift
                isShiftLocked = true
            }
        } else {
            // 如果當前不是 Shift 狀態，則啟用臨時 Shift
            isShifted = true
            isShiftLocked = false
        }
        
        // 更新 Shift 按鈕外觀
        updateShiftButtonAppearance()
        
        // 更新字母按鍵顯示
        updateLetterKeysForShiftState()
    }
    
    // 切換輸入模式
    func toggleInputMode() {
        // 切換輸入模式狀態
        isBoshiamyMode = !isBoshiamyMode
        
        // 清空已收集的字根和候選字
        collectedRoots = ""
        updateInputCodeDisplay("")
        displayCandidates([])
        
        // 顯示當前模式的提示
        let modeText = isBoshiamyMode ? "嘸蝦米模式" : "英文模式"
        print("切換到\(modeText)，使用初始鍵盤尺寸: \(initialKeyboardWidth) x \(initialKeyboardHeight)")
        
        // 重新建立鍵盤按鍵
        recreateKeyboard()
        
        // 重新設置長按手勢
        DispatchQueue.main.async {
            self.setupLongPressGestures()
        }
    }
    
    // 重新建立整個鍵盤
    private func recreateKeyboard() {
        // 清除現有按鍵
        for subview in keyboardView.subviews {
            subview.removeFromSuperview()
        }
        keyButtons.removeAll()
        
        // 重新創建按鍵
        DispatchQueue.main.async {
            self.createKeyButtons()
        }
    }
    
    // 關閉鍵盤方法
    override func dismissKeyboard() {
        advanceToNextInputMode()
    }
    
    // 使用Auto Layout顯示候選字詞
    
    
    func displayCandidates(_ candidates: [String]) {
        // 清除現有的候選字按鈕
        for button in candidateButtons {
            button.removeFromSuperview()
        }
        candidateButtons.removeAll()
        
        // 移除舊的視圖（除了輸入標籤和位置標記）
        for subview in candidateView.subviews {
            if subview != inputCodeLabel && ((subview.backgroundColor?.isEqual(UIColor.clear)) == nil) {
                subview.removeFromSuperview()
            }
        }
        
        // 如果沒有候選字，縮小候選字視圖高度但保留輸入字碼顯示
        if candidates.isEmpty {
            candidateViewHeightConstraint.constant = 50
            view.layoutIfNeeded()
            return
        }
        
        // 有候選字時，調整高度
        candidateViewHeightConstraint.constant = 50
        
        // 創建候選字堆疊視圖 - 所有候選字依序排列在輸入標籤右側
        let candidatesStackView = UIStackView()
        candidatesStackView.axis = .horizontal
        candidatesStackView.spacing = 5
        candidatesStackView.alignment = .center
        candidatesStackView.translatesAutoresizingMaskIntoConstraints = false
        candidateView.addSubview(candidatesStackView)
        
        // 設置候選字堆疊視圖約束
        NSLayoutConstraint.activate([
            candidatesStackView.centerYAnchor.constraint(equalTo: candidateView.centerYAnchor),
            candidatesStackView.leadingAnchor.constraint(equalTo: inputCodeLabel.trailingAnchor, constant: 10),
            candidatesStackView.trailingAnchor.constraint(lessThanOrEqualTo: candidateView.trailingAnchor, constant: -5)
        ])
        
        // 依序添加候選字按鈕
        for (index, candidate) in candidates.enumerated() {
            let button = createCandidateButton(for: candidate, at: index)
            candidatesStackView.addArrangedSubview(button)
            candidateButtons.append(button)
        }
        
        // 更新內容大小以支持滾動
        candidateView.layoutIfNeeded()
        let stackWidth = candidatesStackView.frame.width
        let inputWidth = inputCodeLabel.frame.width
        let totalWidth = inputCodeLabel.frame.minX + inputWidth + 10 + stackWidth + 5
        candidateView.contentSize = CGSize(width: max(totalWidth, candidateView.frame.width), height: 40)
    }
    
    // 輔助方法：創建候選按鈕
    
    private func createCandidateButton(for candidate: String, at index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white
        button.layer.cornerRadius = 4
        button.setTitle(candidate, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 22) // 添加這一行設定字體大小
        button.tag = index
        button.addTarget(self, action: #selector(candidateSelected(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // 設置按鈕尺寸約束
        let buttonWidth = max(50, candidate.count * 36) // 修改這裡，增加寬度以適應更大的字體
        button.widthAnchor.constraint(equalToConstant: CGFloat(buttonWidth)).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true // 修改這裡，從30改為40
        
        return button
    }
    
    // 候選字被選中
    @objc func candidateSelected(_ sender: UIButton) {
        let candidate = sender.title(for: .normal) ?? ""
        
        // 根據同音字反查階段處理選擇
       if isHomophoneLookupMode {
           switch homophoneLookupStage {
           case 1:  // 選擇字的階段
               // 保存選擇的字
               lastSelectedCharacter = candidate
               
               // 查詢該字的注音
               if let bopomofoList = bopomofoDictionary[candidate], !bopomofoList.isEmpty {
                   homophoneLookupStage = 2  // 進入注音選擇階段
                   
                   // 更新輸入提示
                   updateInputCodeDisplay("選擇「" + candidate + "」的注音")
                   
                   // 顯示注音列表作為候選字
                   displayCandidates(bopomofoList)
               } else {
                   // 找不到注音，直接輸入字並退出反查模式
                   textDocumentProxy.insertText(candidate)
                   exitHomophoneLookupMode()
               }
               break
               
           case 2:  // 選擇注音的階段
               // 查詢該注音的同音字
               if let homophoneList = bopomospellDictionary[candidate], !homophoneList.isEmpty {
                   homophoneLookupStage = 3  // 進入同音字選擇階段
                   
                   // 更新輸入提示
                   updateInputCodeDisplay("「" + candidate + "」")
                   
                   // 顯示同音字列表
                   displayCandidates(homophoneList)
               } else {
                   // 找不到同音字，退回到字根輸入階段
                   homophoneLookupStage = 1
                   updateInputCodeDisplay("同音字反查：" + collectedRoots)
                   
                   // 重新顯示字根對應的候選字
                   let candidates = lookupBoshiamyDictionary(collectedRoots)
                   displayCandidates(candidates)
               }
               break
               
           case 3:  // 選擇同音字的階段
               // 輸入選中的同音字
               textDocumentProxy.insertText(candidate)
               
               // 退出反查模式
               exitHomophoneLookupMode()
               break
               
           default:
               break
           }
           
       } else {
           // 原有的候選字選擇處理...
           // 輸入選中的字詞
           textDocumentProxy.insertText(candidate)
           
           // 清除已輸入的字根
           collectedRoots = ""
           
           // 更新輸入字碼顯示
           updateInputCodeDisplay("")
           
           // 清空候選字區域
           displayCandidates([])
           
           
       }
   }
    
    
    // 添加按鍵視覺反饋
    func animateButton(_ button: UIButton) {
        if var config = button.configuration {
            // 保存原始背景顏色
            let originalColor = config.background.backgroundColor
            
            // 設置按下時的背景顏色
            config.background.backgroundColor = UIColor.lightGray
            button.configuration = config
            
            // 延遲後恢復原始背景顏色
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                var updatedConfig = button.configuration
                updatedConfig?.background.backgroundColor = originalColor
                button.configuration = updatedConfig
            }
        } else {
            // 舊版按鈕動畫方法（後備）
            UIView.animate(withDuration: 0.1, animations: {
                button.backgroundColor = UIColor.lightGray
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    button.backgroundColor = UIColor.white
                }
            }
        }
    }
    
    //--------------------side buttons-------------------
    // 在 createKeyButtons 方法中實現左右側欄
    private func createKeyButtons() {
        print("創建按鍵 - \(isBoshiamyMode ? "嘸蝦米模式" : "英文模式")")
        
        // 儲存初始鍵盤尺寸和方向（只做一次）
            if !initialKeyboardMetricsSet {
                initialKeyboardWidth = view.bounds.width
                initialKeyboardHeight = view.bounds.height
                initialIsLandscape = initialKeyboardWidth > initialKeyboardHeight
                initialKeyboardMetricsSet = true
                print("儲存初始鍵盤尺寸: \(initialKeyboardWidth) x \(initialKeyboardHeight), 是否橫向: \(initialIsLandscape)")
            }
            
            // 使用儲存的初始尺寸判斷，而不是當前視圖尺寸
            let isLandscape = initialIsLandscape
            let isIPhonePortrait = isIPhone && !isLandscape
        
        // 設定字型大小 - 在此處統一設定，不論是何種模式
            if isIPhonePortrait {
                titleFontSize = 8   // iPhone 直式模式使用更小的次要標籤字型
                subtitleFontSize = 10 // iPhone 直式模式使用更小的主要標籤字型
            } else if isLandscape {
                titleFontSize = 10
                subtitleFontSize = 16
            } else {
                //ipad直
                titleFontSize = 12
                subtitleFontSize = 22
            }
        
            // 根據設備類型和方向調整間距和邊距
            let buttonSpacing: CGFloat
            let rowSpacing: CGFloat
            let keyboardPadding: CGFloat
            
            if isIPhonePortrait {
                // iPhone 直式模式下的優化設定
                buttonSpacing = 2  // 更小的按鈕間距
                rowSpacing = 3     // 更小的行間距
                keyboardPadding = 3  // 更小的邊距
            } else if isLandscape {
                // 橫向模式設定
                buttonSpacing = 4
                rowSpacing = 4
                keyboardPadding = 6
            } else {
                // 其他情況（iPad等）
                buttonSpacing = 4
                rowSpacing = 8
                keyboardPadding = 5
            }
            
            // 創建主容器
            let mainHorizontalStackView = UIStackView()
            mainHorizontalStackView.axis = .horizontal
            mainHorizontalStackView.distribution = .fill
            mainHorizontalStackView.spacing = buttonSpacing  // 使用調整後的間距
            mainHorizontalStackView.translatesAutoresizingMaskIntoConstraints = false
            keyboardView.addSubview(mainHorizontalStackView)
            
            // 設置主容器約束
            NSLayoutConstraint.activate([
                mainHorizontalStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: keyboardPadding),
                mainHorizontalStackView.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: keyboardPadding),
                mainHorizontalStackView.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -keyboardPadding),
                mainHorizontalStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -keyboardPadding)
            ])
            
            // 創建左側欄 - 為 iPhone 直式模式調整寬度
            let sideColumnWidth: CGFloat = isIPhonePortrait ? 32 : (isLandscape ? 45 : 40)
            let leftColumnStackView = createSideColumn(isLeft: true, isLandscape: isLandscape)

            leftColumnStackView.setContentHuggingPriority(UILayoutPriority.defaultHigh + 10, for: .horizontal)

            mainHorizontalStackView.addArrangedSubview(leftColumnStackView)
            
            // 創建主鍵盤容器
            let mainKeyboardStackView = UIStackView()
            mainKeyboardStackView.axis = .vertical
            mainKeyboardStackView.distribution = .fill
            mainKeyboardStackView.spacing = rowSpacing  // 使用調整後的行間距
            mainKeyboardStackView.translatesAutoresizingMaskIntoConstraints = false
            mainHorizontalStackView.addArrangedSubview(mainKeyboardStackView)
        
            
            // 選擇當前佈局和次要標籤
            let currentLayout = isBoshiamyMode ? boshiamySymbols : keyboardRows
            let currentSecondaryLabels = isBoshiamyMode ? boshiamySecondaryLabels : secondaryLabels
            
            // 逐行創建主鍵盤按鍵
            for (rowIndex, row) in currentLayout.enumerated() {
                let rowStackView = UIStackView()
                rowStackView.axis = .horizontal
                
                // 添加高度約束，可以為不同行設定不同高度
                    let rowHeight: CGFloat
                    if rowIndex == currentLayout.count - 1 {
                        rowHeight = 80  // 最後一行（空格鍵所在行）高度
                    } else {
                        rowHeight = 60  // 其他行高度
                    }
                rowStackView.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
                mainKeyboardStackView.addArrangedSubview(rowStackView)
                
                rowStackView.spacing = buttonSpacing  // 使用調整後的按鈕間距
                rowStackView.translatesAutoresizingMaskIntoConstraints = false
                
                var rowButtons = [UIButton]()
                
                for (keyIndex, keyTitle) in row.enumerated() {
                    // 創建按鈕
                    let button = UIButton(type: .system)
                    button.layer.cornerRadius = isIPhonePortrait ? 3 : 5  // iPhone 直式模式下使用更小的圓角
                    button.layer.borderWidth = isIPhonePortrait ? 0.3 : 0.5  // iPhone 直式模式下使用更細的邊框
                    button.layer.borderColor = UIColor.darkGray.cgColor
                    button.tag = rowIndex * 100 + keyIndex
                    button.addTarget(self, action: #selector(keyPressed(_:)), for: .touchUpInside)
                    button.translatesAutoresizingMaskIntoConstraints = false
                    
                    // 使用 UIButtonConfiguration 設置按鈕樣式
                    var config = UIButton.Configuration.plain()
                    config.baseForegroundColor = UIColor.black
                    config.background.backgroundColor = UIColor.white
                    
                
                    
                    // 添加次要標籤（如果有且不是 iPhone）
                    if rowIndex < currentSecondaryLabels.count && keyIndex < currentSecondaryLabels[rowIndex].count {
                        let secondaryText = currentSecondaryLabels[rowIndex][keyIndex]
                        if !secondaryText.isEmpty && !isIPhone {
                            // 只有在非 iPhone 設備上才顯示次要標籤
                            config.titleAlignment = .center
                            config.title = secondaryText
                            config.subtitle = keyTitle
                            config.titlePadding = 2
                            
                            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                                var outgoing = incoming
                                outgoing.font = UIFont.systemFont(ofSize: self.titleFontSize)
                                outgoing.foregroundColor = UIColor.darkGray
                                return outgoing
                            }
                            
                            config.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                                var outgoing = incoming
                                outgoing.font = UIFont.systemFont(ofSize: self.subtitleFontSize)
                                return outgoing
                            }
                        } else {
                            // iPhone 設備或沒有次要標籤
                            config.title = keyTitle
                            
                            // 根據設備類型和方向設置字型大小
                            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                                var outgoing = incoming
                                outgoing.font = UIFont.systemFont(ofSize: self.subtitleFontSize)
                                return outgoing
                            }
                        }
                    } else {
                        config.title = keyTitle
                        
                        // 根據設備類型和方向設置字型大小
                        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                            var outgoing = incoming
                            outgoing.font = UIFont.systemFont(ofSize: self.subtitleFontSize)
                            return outgoing
                        }
                    }
                    
                    button.configuration = config
                    
                    // 最後一行特別處理
                    if rowIndex == currentLayout.count - 1 {
                        if keyTitle.contains("space") {
                            // 空格鍵設置低優先級，讓它佔據剩餘空間
                            button.setContentHuggingPriority(.defaultLow - 100, for: .horizontal)
                            button.setContentCompressionResistancePriority(.defaultLow - 100, for: .horizontal)
                        } else {
                            // 左右兩個按鍵設置高優先級
                            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                            button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
                        }
                    }
                    
                    // 添加到堆疊視圖和數組
                    rowStackView.addArrangedSubview(button)
                    rowButtons.append(button)
                }
                
                // 添加這一行到主鍵盤堆疊視圖
                mainKeyboardStackView.addArrangedSubview(rowStackView)
                keyButtons.append(rowButtons)
            }
            
            // 創建右側欄 - 為 iPhone 直式模式調整寬度
            let rightColumnStackView = createSideColumn(isLeft: false, isLandscape: isLandscape, width: sideColumnWidth)
            rightColumnStackView.setContentHuggingPriority(.defaultHigh + 10, for: .horizontal)
            mainHorizontalStackView.addArrangedSubview(rightColumnStackView)
        // 後處理：為最後一行的左右按鍵設置固定寬度
        if let lastRowButtons = keyButtons.last, lastRowButtons.count == 3 {
            // 計算標準按鍵寬度（基於倒數第二行按鍵數量）
            let standardRowIndex = currentLayout.count - 2
            if standardRowIndex >= 0 && standardRowIndex < keyButtons.count {
                let standardRowButtonCount = keyButtons[standardRowIndex].count
                let availableWidth = view.bounds.width - 16  // 減去左右邊距
                let buttonSpacing = isLandscape ? 4.0 : 6.0  // 使用 CGFloat
                let totalSpacing = buttonSpacing * CGFloat(standardRowButtonCount - 1)  // 將 Int 轉換為 CGFloat
                let standardKeyWidth = (availableWidth - totalSpacing) / CGFloat(standardRowButtonCount)  // 轉換為 CGFloat
                
                // 設置最後一行左右按鍵的固定寬度
                lastRowButtons[0].widthAnchor.constraint(equalToConstant: standardKeyWidth).isActive = true
                lastRowButtons[2].widthAnchor.constraint(equalToConstant: standardKeyWidth).isActive = true
                
                // 空格鍵自動填充剩餘空間
            }
        }
        
        // 在鍵盤創建完成後設置長按手勢
        DispatchQueue.main.async {
            self.setupLongPressGestures()
        }
        
        DispatchQueue.main.async {
            // 確保視圖尺寸穩定後再設置寬度
            self.adjustLastRowButtonWidths()
        }
    }
    
    
    // 然後添加一個新的方法用於調整最後一行按鍵寬度
    private func adjustLastRowButtonWidths() {
        // 確保鍵盤已經創建且有最後一行
        guard !keyButtons.isEmpty, let lastRowButtons = keyButtons.last, lastRowButtons.count == 3 else {
            return
        }
        
        // 確保有標準行用於比較
        let standardRowIndex = keyButtons.count - 2
        guard standardRowIndex >= 0, standardRowIndex < keyButtons.count else {
            return
        }
        
        // 獲取視圖當前的實際寬度
        let keyboardWidth = keyboardView.bounds.width
        if keyboardWidth <= 0 {
            // 視圖寬度不正確，再次延遲
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.adjustLastRowButtonWidths()
            }
            return
        }
        
        // 計算標準按鍵寬度
        let isLandscape = view.bounds.width > view.bounds.height
        let standardRowButtonCount = keyButtons[standardRowIndex].count
        let availableWidth = keyboardWidth - 16.0  // 減去左右邊距
        let buttonSpacing = isLandscape ? 4.0 : 6.0
        let totalSpacing = buttonSpacing * CGFloat(standardRowButtonCount - 1)
        let standardKeyWidth = (availableWidth - totalSpacing) / CGFloat(standardRowButtonCount)
        
        // 移除之前可能已存在的寬度約束
        lastRowButtons[0].constraints.forEach { constraint in
            if constraint.firstAttribute == .width {
                lastRowButtons[0].removeConstraint(constraint)
            }
        }
        lastRowButtons[2].constraints.forEach { constraint in
            if constraint.firstAttribute == .width {
                lastRowButtons[2].removeConstraint(constraint)
            }
        }
        
        // 設置左右按鍵的固定寬度
        lastRowButtons[0].widthAnchor.constraint(equalToConstant: standardKeyWidth).isActive = true
        lastRowButtons[2].widthAnchor.constraint(equalToConstant: standardKeyWidth).isActive = true
        
        // 強制更新佈局
        keyboardView.layoutIfNeeded()
        
        print("調整後的標準鍵寬: \(standardKeyWidth), 鍵盤寬度: \(keyboardWidth)")
    }
    
    
    // 創建側欄的輔助方法
    private func createSideColumn(isLeft: Bool, isLandscape: Bool, width: CGFloat = 0) -> UIStackView {
        // 創建垂直堆疊視圖作為側欄容器
        let columnStackView = UIStackView()
        columnStackView.axis = .vertical
        columnStackView.distribution = .fillEqually // 修改為均等分布
        columnStackView.spacing = 12 // 設定為固定間距12
        columnStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 固定側欄寬度
        // 根據設備類型和方向設置側欄寬度
        let sideColumnWidth: CGFloat
        if isIPhone {
            if isLandscape {
                sideColumnWidth = 50  // iPhone 橫向
            } else {
                sideColumnWidth = 40  // iPhone 縱向
            }
        } else {
            //ipad
            if isLandscape {
                sideColumnWidth = 70  // iPad 橫向
            } else {
                sideColumnWidth = 60  // iPad 縱向
            }
        }
        columnStackView.widthAnchor.constraint(equalToConstant: sideColumnWidth).isActive = true
        
        // 定義側欄按鍵
        let topButtonTitle = "⌫"  // backspace
        let bottomButtonTitle = "⏎"  // enter
        
        // 創建頂部按鈕 (backspace)
        let topButton = UIButton(type: .system)
        topButton.layer.cornerRadius = 5
        topButton.layer.borderWidth = 0.5
        topButton.layer.borderColor = UIColor.darkGray.cgColor
        topButton.translatesAutoresizingMaskIntoConstraints = false
        
        var topConfig = UIButton.Configuration.plain()
        topConfig.title = topButtonTitle
        topConfig.baseForegroundColor = UIColor.black
        topConfig.background.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        // 添加字體設置
        topConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: isLandscape ? 16 : 18)  // 設置與底部按鈕相同的字體大小
            return outgoing
        }
        topButton.configuration = topConfig
        
        // 設置標籤，區分左右側欄
        let tagOffset = isLeft ? 1000 : 2000
        topButton.tag = tagOffset
        topButton.addTarget(self, action: #selector(sideButtonPressed(_:)), for: .touchUpInside)
        
        // 創建底部按鈕 (enter)
        let bottomButton = UIButton(type: .system)
        bottomButton.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        bottomButton.setTitleColor(UIColor.black, for: .normal)
        bottomButton.layer.cornerRadius = 5
        bottomButton.layer.borderWidth = 0.5
        bottomButton.layer.borderColor = UIColor.darkGray.cgColor
        bottomButton.setTitle(bottomButtonTitle, for: .normal)
        bottomButton.titleLabel?.font = UIFont.systemFont(ofSize: isLandscape ? 16 : 18)
        
        // 設置標籤
        bottomButton.tag = tagOffset + 1
        bottomButton.addTarget(self, action: #selector(sideButtonPressed(_:)), for: .touchUpInside)
        bottomButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 移除中間空白部分，讓兩個按鈕平均分布整個高度
        columnStackView.addArrangedSubview(topButton)
        columnStackView.addArrangedSubview(bottomButton)
        
        return columnStackView
    }
    
    // 處理側欄按鍵點擊
    @objc func sideButtonPressed(_ sender: UIButton) {
        animateButton(sender)
        
        let tag = sender.tag
        
        // 處理backspace（左上或右上按鍵）
        if tag == 1000 || tag == 2000 {
            // 執行單擊刪除操作
            handleDeleteAction()
            
            // 添加長按手勢
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressDelete(_:)))
            longPress.minimumPressDuration = 0.5  // 0.5秒後觸發長按
            sender.addGestureRecognizer(longPress)
        } else if tag == 1001 || tag == 2001 {
            // enter - 左下或右下按鍵
            textDocumentProxy.insertText("\n")
        }
    }
    // 新增 - 處理長按刪除手勢
    @objc func handleLongPressDelete(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            // 開始長按，啟動連續刪除
            isLongPressDeleteActive = true
            startDeleteTimer()
        case .ended, .cancelled, .failed:
            // 結束長按，停止連續刪除
            isLongPressDeleteActive = false
            stopDeleteTimer()
        default:
            break
        }
    }

    // 新增 - 啟動刪除定時器
    private func startDeleteTimer() {
        // 先停止可能已存在的定時器
        stopDeleteTimer()
        
        // 建立新的定時器，每0.1秒執行一次刪除操作
        deleteTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(timerDeleteAction), userInfo: nil, repeats: true)
    }

    // 新增 - 停止刪除定時器
    private func stopDeleteTimer() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }

    // 新增 - 定時器觸發的刪除操作
    @objc private func timerDeleteAction() {
        if isLongPressDeleteActive {
            handleDeleteAction()
        }
    }

    // 新增 - 統一刪除操作的邏輯
    private func handleDeleteAction() {
        // 如果沒有收集的字根，直接退出同音字反查模式
        if collectedRoots.isEmpty {
            exitHomophoneLookupMode()
            textDocumentProxy.deleteBackward()  // 執行一般的刪除操作
            return
        }
        
        // 如果在同音字反查模式下並且有收集的字根
        if isHomophoneLookupMode && !collectedRoots.isEmpty {
            // 刪除最後一個字根
            collectedRoots = String(collectedRoots.dropLast())
            
            // 如果刪除後字根為空，退出反查模式
            if collectedRoots.isEmpty {
                exitHomophoneLookupMode()
                return
            }
            
            // 更新輸入提示和候選字
            updateInputCodeDisplay("同音字反查：" + collectedRoots)
            let candidates = lookupBoshiamyDictionary(collectedRoots)
            displayCandidates(candidates)
        } else if isBoshiamyMode && !collectedRoots.isEmpty {
            // 嘸蝦米模式下的刪除邏輯
            collectedRoots = String(collectedRoots.dropLast())
            
            // 更新輸入字碼顯示
            updateInputCodeDisplay(collectedRoots)
            
            // 重新查詢候選字
            if collectedRoots.isEmpty {
                // 如果沒有輸入的字根了，清空候選字區域
                displayCandidates([])
            } else {
                // 否則，查詢新的候選字
                let candidates = lookupBoshiamyDictionary(collectedRoots)
                displayCandidates(candidates)
            }
        } else {
            // 普通刪除操作
            textDocumentProxy.deleteBackward()
        }
    }
    
    // 處理嘸蝦米輸入邏輯
    func handleBoshiamyInput(_ key: String) {
        // 只取字母部分作為字根（忽略空格）
        let rootKey = key.components(separatedBy: " ").first ?? key
        
        // 檢查是否為「、」符號，觸發同音字反查模式
        if rootKey == "、" {
            startHomophoneLookup()
            return
        }
    
        // 檢查是否為數字
        if rootKey.count == 1 && "0123456789".contains(rootKey) {
            // 如果是數字，直接輸入而不收集字根
            textDocumentProxy.insertText(rootKey)
            return
        }
        
        // 收集字根
        collectedRoots += rootKey
        
        // 更新輸入字碼顯示
        updateInputCodeDisplay(collectedRoots)
        
        // 查詢嘸蝦米字典，獲取候選字
        let candidates = lookupBoshiamyDictionary(collectedRoots)
        
        // 顯示候選字詞
        displayCandidates(candidates)
    }
    
    // 查詢字典方法 - 直接從內存字典查詢
    func lookupBoshiamyDictionary(_ roots: String) -> [String] {
        let startTime = CFAbsoluteTimeGetCurrent()
        var results = [String]()
        
        guard let db = database, db.isOpen else {
            print("資料庫未開啟")
            return results
        }
        
        // 執行查詢
        if let resultSet = db.executeQuery("SELECT cw FROM liuDB WHERE spell = ?", withArgumentsIn: [roots]) {
            while resultSet.next() {
                if let character = resultSet.string(forColumn: "cw") {
                    results.append(character)
                }
            }
            resultSet.close()
        } else {
            print("查詢失敗: \(db.lastErrorMessage())")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("查詢字根: \(roots), 找到 \(results.count) 個候選字, 耗時: \((endTime-startTime)*1000) ms")
        
        return results
    }
    
    // 載入CSV字典方法
    func loadBoshiamyDictionaryFromCSV() {
        print("開始載入CSV字典...")
        
        // 首先嘗試從Bundle加載
        if let csvPath = Bundle.main.path(forResource: "liuDB", ofType: "csv") {
            loadCSVFromPath(csvPath)
            return
        }
        
        // 如果Bundle中沒有，嘗試從Documents目錄加載
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docDir.appendingPathComponent("liuDB.csv")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            loadCSVFromPath(fileURL.path)
            return
        }
        
        print("找不到CSV檔案，將使用內建的基本字根")
    }
    
    // 從指定路徑載入CSV
    
    private func loadCSVFromPath(_ path: String) {
        do {
            let csvContent = try String(contentsOfFile: path, encoding: .utf8)
            let rows = csvContent.components(separatedBy: .newlines)
            var loadedCount = 0
            
            for row in rows where !row.isEmpty {
                let columns = row.components(separatedBy: ",")
                // 檢查行是否有足夠的列
                if columns.count >= 3 {
                    // CSV格式: uid,spell,cw
                    // 我們需要spell和cw欄位
                    let spell = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let character = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !spell.isEmpty && !character.isEmpty {
                        if inMemoryBoshiamyDict[spell] == nil {
                            inMemoryBoshiamyDict[spell] = [character]
                        } else {
                            inMemoryBoshiamyDict[spell]?.append(character)
                        }
                        loadedCount += 1
                    }
                }
            }
            
            print("從CSV載入了 \(loadedCount) 筆資料, \(inMemoryBoshiamyDict.count) 個字根")
            
            // 輸出一些範例
//            if let sampleKeys = inMemoryBoshiamyDict.keys.prefix(5) {
//                for key in Array(sampleKeys) {
//                    if let values = inMemoryBoshiamyDict[key] {
//                        print("範例: 字根 '\(key)' -> \(values)")
//                    }
//                }
//            }
        } catch {
            print("讀取CSV檔案失敗: \(error)")
        }
    }
    deinit {
        database?.close()
    }
    //------------同音字反查
    // 2. 加載注音數據的方法
       func loadBopomofoData() {
           print("開始載入注音資料...")
           
           // 載入 bopomofo.csv (字 -> 注音)
           if let bopomofoPath = Bundle.main.path(forResource: "bopomofo", ofType: "csv") {
               do {
                   let content = try String(contentsOfFile: bopomofoPath, encoding: .utf8)
                   let rows = content.components(separatedBy: .newlines)
                   
                   for row in rows where !row.isEmpty {
                       let columns = row.components(separatedBy: ",")
                       if columns.count >= 3 {
                           // 格式: id,字,注音
                           let character = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                           let bopomofo = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                           
                           if !character.isEmpty && !bopomofo.isEmpty {
                               if bopomofoDictionary[character] == nil {
                                   bopomofoDictionary[character] = [bopomofo]
                               } else {
                                   bopomofoDictionary[character]?.append(bopomofo)
                               }
                           }
                       }
                   }
                   
                   print("從bopomofo.csv載入了 \(bopomofoDictionary.count) 個字的注音")
               } catch {
                   print("讀取bopomofo.csv失敗: \(error)")
               }
           }
           
           // 載入 bopomospell.csv (注音 -> 同音字)
           if let bopomospellPath = Bundle.main.path(forResource: "bopomospell", ofType: "csv") {
               do {
                   let content = try String(contentsOfFile: bopomospellPath, encoding: .utf8)
                   let rows = content.components(separatedBy: .newlines)
                   
                   for row in rows where !row.isEmpty {
                       let columns = row.components(separatedBy: ",")
                       if columns.count >= 3 {
                           // 格式: id,注音,字
                           let bopomofo = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                           let character = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                           
                           if !bopomofo.isEmpty && !character.isEmpty {
                               if bopomospellDictionary[bopomofo] == nil {
                                   bopomospellDictionary[bopomofo] = [character]
                               } else {
                                   bopomospellDictionary[bopomofo]?.append(character)
                               }
                           }
                       }
                   }
                   
                   print("從bopomospell.csv載入了 \(bopomospellDictionary.count) 個注音的同音字")
               } catch {
                   print("讀取bopomospell.csv失敗: \(error)")
               }
           }
       }
    // 4. 開始同音字反查模式
        func startHomophoneLookup() {
            isHomophoneLookupMode = true
            homophoneLookupStage = 1  // 進入輸入字根階段
            collectedRoots = ""  // 清空收集的字根
            
            // 更新輸入提示
            updateInputCodeDisplay("同音字反查：")
            
            // 清空候選字
            displayCandidates([])
        }
        
        // 5. 處理同音字反查模式下的按鍵
        func handleHomophoneLookupKeyPress(_ key: String) {
            // 處理特殊按鍵
            if key.contains("space") || key.contains("  　") {
                handleSpaceInLookupMode()
                return
            } else if key.contains("delete") || key.contains("⌫") {
                handleDeleteInLookupMode()
                return
            } else if key.contains("中") || key.contains("英") || key.contains("return") || key.contains("⏎") {
                // 特殊按鍵直接退出反查模式
                exitHomophoneLookupMode()
                
                // 繼續處理原有功能
                if key.contains("中") || key.contains("英") {
                    toggleInputMode()
                } else if key.contains("return") || key.contains("⏎") {
                    textDocumentProxy.insertText("\n")
                }
                return
            }
            
            // 根據階段處理按鍵
            switch homophoneLookupStage {
            case 1:  // 輸入字根階段
                // 清除字根的按鍵，跳過數字和特殊鍵
                if key.count == 1 && (key >= "A" && key <= "Z" || key >= "a" && key <= "z" || key == "," || key == ".") {
                    // 收集字根
                    collectedRoots += key
                    
                    // 更新輸入字碼顯示
                    updateInputCodeDisplay("同音字反查：" + collectedRoots)
                    
                    // 查詢嘸蝦米字典，獲取候選字
                    let candidates = lookupBoshiamyDictionary(collectedRoots)
                    
                    // 顯示候選字詞
                    displayCandidates(candidates)
                }
                break
                
            case 2:  // 選擇注音階段
                // 這個階段的按鍵處理在 candidateSelected 方法中處理
                break
                
            case 3:  // 選擇同音字階段
                // 這個階段的按鍵處理在 candidateSelected 方法中處理
                break
                
            default:
                break
            }
        }
    // 6. 處理反查模式下的空格鍵
       func handleSpaceInLookupMode() {
           switch homophoneLookupStage {
           case 1:  // 輸入字根階段
               if !collectedRoots.isEmpty && !candidateButtons.isEmpty {
                   // 選擇第一個候選字
                   if let firstCandidateButton = candidateButtons.first {
                       candidateSelected(firstCandidateButton)
                   }
               }
               break
               
           case 2:  // 選擇注音階段
               if !candidateButtons.isEmpty {
                   // 選擇第一個注音
                   if let firstCandidateButton = candidateButtons.first {
                       candidateSelected(firstCandidateButton)
                   }
               }
               break
               
           case 3:  // 選擇同音字階段
               if !candidateButtons.isEmpty {
                   // 選擇第一個同音字
                   if let firstCandidateButton = candidateButtons.first {
                       candidateSelected(firstCandidateButton)
                   }
               }
               break
               
           default:
               break
           }
       }
       
       // 7. 處理反查模式下的刪除鍵
       func handleDeleteInLookupMode() {
           switch homophoneLookupStage {
           case 1:  // 輸入字根階段
               if !collectedRoots.isEmpty {
                   // 刪除最後一個字根
                   collectedRoots = String(collectedRoots.dropLast())
                   
                   // 更新輸入提示
                   updateInputCodeDisplay("同音字反查：" + collectedRoots)
                   
                   if collectedRoots.isEmpty {
                       // 如果字根為空，清空候選字
                       displayCandidates([])
                   } else {
                       // 重新查詢候選字
                       let candidates = lookupBoshiamyDictionary(collectedRoots)
                       displayCandidates(candidates)
                   }
               } else {
                   // 如果字根為空，退出反查模式
                   exitHomophoneLookupMode()
               }
               break
               
           case 2, 3:  // 選擇注音或同音字階段
               // 返回上一個階段
               homophoneLookupStage -= 1
               
               if homophoneLookupStage == 1 {
                   // 返回字根輸入階段
                   updateInputCodeDisplay("同音字反查：" + collectedRoots)
                   let candidates = lookupBoshiamyDictionary(collectedRoots)
                   displayCandidates(candidates)
               } else if homophoneLookupStage == 2 {
                   // 返回注音選擇階段
                   updateInputCodeDisplay("選擇「" + lastSelectedCharacter + "」的注音")
                   let bopomofoList = bopomofoDictionary[lastSelectedCharacter] ?? []
                   displayCandidates(bopomofoList)
               }
               break
               
           default:
               break
           }
       }
       
       // 8. 退出同音字反查模式
       func exitHomophoneLookupMode() {
           isHomophoneLookupMode = false
           homophoneLookupStage = 0
           collectedRoots = ""
           lastSelectedCharacter = ""
           
           // 清空輸入提示和候選字
           updateInputCodeDisplay("")
           displayCandidates([])
       }
    
    
    
}
