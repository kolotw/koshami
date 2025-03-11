import UIKit
import FMDB

class KeyboardViewController: UIInputViewController {
    var assoDB: FMDatabase?
    // 添加緩衝區屬性
    var assoCharBuffer: [(previous: String, current: String)] = []
    var lastAssoWriteTime: TimeInterval = 0
    let assoWriteInterval: TimeInterval = 10 // 30秒
    
    enum DeviceState {
        case iPhonePortrait
        case iPhoneLandscape
        case iPadPortrait
        case iPadLandscape
    }
    struct KeyboardMetrics {
        var deviceState: DeviceState
        var titleFontSize: CGFloat
        var subtitleFontSize: CGFloat
        var buttonSpacing: CGFloat
        var rowSpacing: CGFloat
        var keyboardPadding: CGFloat
        var keyHeight: CGFloat
        var sideColumnWidth: CGFloat
        var candidateViewHeight: CGFloat
        var functionKeyWidthRatio: CGFloat
        var keyboardHeight: CGFloat  // 新增鍵盤總高度參數
        
        init(deviceState: DeviceState) {
            self.deviceState = deviceState
            
            switch deviceState {
            case .iPhonePortrait:
                titleFontSize = 8
                subtitleFontSize = 14
                buttonSpacing = 2
                rowSpacing = 3
                keyboardPadding = 2
                keyHeight = 65
                sideColumnWidth = 40
                candidateViewHeight = 45
                functionKeyWidthRatio = 0.12
                keyboardHeight = 320  // 設定 iPhone 直向總高度
                
            case .iPhoneLandscape:
                titleFontSize = 10
                subtitleFontSize = 14
                buttonSpacing = 2
                rowSpacing = 2
                keyboardPadding = 3
                keyHeight = 24
                sideColumnWidth = 40
                candidateViewHeight = 40
                functionKeyWidthRatio = 0.12
                keyboardHeight = 160  // 設定 iPhone 橫向總高度
                
            case .iPadPortrait:
                titleFontSize = 12
                subtitleFontSize = 18
                buttonSpacing = 3
                rowSpacing = 4
                keyboardPadding = 4
                keyHeight = 80
                sideColumnWidth = 100
                candidateViewHeight = 60
                functionKeyWidthRatio = 0.2
                keyboardHeight = 520  // 設定 iPad 直向總高度
                
            case .iPadLandscape:
                titleFontSize = 14
                subtitleFontSize = 20
                buttonSpacing = 4
                rowSpacing = 5
                keyboardPadding = 5
                keyHeight = 50
                sideColumnWidth = 60
                candidateViewHeight = 50
                functionKeyWidthRatio = 0.25
                keyboardHeight = 260  // 設定 iPad 橫向總高度
            }
        }
    }
    
    var database: FMDatabase?
    var isIPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    // 修改英文鍵盤布局，添加符號鍵
    let keyboardRows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "'"],
        ["⇧", "z", "x", "c", "v", "b", "n", "m", ",", "."],
        ["🌐", "符", "space", "中", "⏎"]
    ]
    let secondaryLabels = [
        ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"],
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],  // 填入大寫字母
        ["A", "S", "D", "F", "G", "H", "J", "K", "L", "\""],
        ["", "Z", "X", "C", "V", "B", "N", "M", "<", ">"],  // 第一個是shift鍵，保留空字串
        ["", "", "", "", ""]
    ]

    // 修改嘸蝦米鍵盤布局，添加符號鍵
    let boshiamySymbols = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L", "、"],
        ["Z", "X", "C", "V", "B", "N", "M", "，", "."],
        ["🌐", "符", "空白鍵", "英", "⏎"]
    ]
    let boshiamySecondaryLabels = [
        ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],  // 填入小寫字母
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "/"],
        ["z", "x", "c", "v", "b", "n", "m", "<", ">"],
        ["", "", "", "", ""]
    ]

    // 修改符號鍵盤布局
    let symbolRows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["@", "#", "$", "&", "*", "(", ")", "'", "\"", "-"],
        ["%", "+", "=", "/", ";", ":", ",", ".", "!", "?"],
        ["|", "~", "¥", "_", "^", "[", "]", "{", "}", "\\"],
        ["🌐", " ", "space", "中", "⏎"]
    ]

    // 為符號鍵盤添加次要標籤
    let symbolSecondaryLabels = [
        ["", "", "", "", "", "", "", "", "", ""],
        ["", "", "", "", "", "", "", "", "", ""],
        ["", "", "", "", "", "", "", "", "", ""],
        ["", "", "", "", "", "", "", "", "", ""],
        ["", "", "", "",""]
    ]
    
    // 輸入模式標誌
    var isSymbolMode = false
    
    // 視圖和按鍵
    var keyboardView: UIView!
    var candidateView: UIScrollView!
    var keyButtons = [[UIButton]]()
    var candidateButtons = [UIButton]()
    
    // 狀態變數
    var isShifted = false
    var isShiftLocked = false  // 用於區分臨時大寫和鎖定大寫
    var collectedRoots = ""
    
    // 約束參考
    var candidateViewHeightConstraint: NSLayoutConstraint!
    
    var isBoshiamyMode = true  // true 為嘸蝦米模式，false 為英文模式
    var inputCodeLabel: UILabel!
    
    // 同音字反查功能所需的屬性
    var isHomophoneLookupMode = false  // 表示是否處於同音字反查模式
    var homophoneLookupStage = 0       // 反查階段: 0=未開始, 1=輸入字根, 2=選擇注音, 3=選擇同音字
    var lastSelectedCharacter = ""     // 最後選擇的字
    var bopomofoDictionary: [String: [String]] = [:]  // 字 -> 注音列表
    var bopomospellDictionary: [String: [String]] = [:]  // 注音 -> 字列表
    
    private var deleteTimer: Timer?
    private var isLongPressDeleteActive = false
    
    // 鍵盤尺寸參數
    var keyboardMetrics: KeyboardMetrics!
    
    // 獲取當前裝置狀態
    
    func getCurrentDeviceState() -> DeviceState {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        
        // 主要使用畫面大小來判斷方向，這比裝置方向更可靠
        let screenSize = UIScreen.main.bounds.size
        let isLandscape = screenSize.width > screenSize.height
        
        //print("螢幕大小: \(screenSize), 判斷為\(isLandscape ? "橫向" : "直向")")
        
        if isPhone {
            return isLandscape ? .iPhoneLandscape : .iPhonePortrait
        } else {
            return isLandscape ? .iPadLandscape : .iPadPortrait
        }
    }

    // 獲取當前尺寸參數
    func updateKeyboardMetrics() {
        // 獲取當前狀態
        let currentState = getCurrentDeviceState()
        
        // 檢查是否需要更新
        if currentState != keyboardMetrics.deviceState {
            print("設備狀態更改: \(keyboardMetrics.deviceState) -> \(currentState)")
            
            // 更新尺寸參數
            keyboardMetrics = KeyboardMetrics(deviceState: currentState)
            
            // 應用新的尺寸參數
            applyKeyboardMetrics()
        }
    }

    // 應用尺寸參數到視圖
    func applyKeyboardMetrics() {
        // 更新候選區高度約束
        candidateViewHeightConstraint.constant = keyboardMetrics.candidateViewHeight
        
        // 更新輸入碼顯示字體
        inputCodeLabel.font = UIFont.systemFont(ofSize: keyboardMetrics.subtitleFontSize)
        
        // 更新候選按鈕字體
        for button in candidateButtons {
            button.titleLabel?.font = UIFont.systemFont(ofSize: keyboardMetrics.subtitleFontSize)
        }
        
        // 立即更新佈局
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // 重新創建鍵盤按鈕
        DispatchQueue.main.async {
            self.recreateKeyboard()
        }
    }
    
    // 初始化資料庫
    func initDatabase() {
        // 找到 Bundle 中的資料庫
        guard let bundleDBPath = Bundle.main.path(forResource: "liu", ofType: "db") else {
            print("在 Bundle 中找不到資料庫檔案")
            return
        }
        
        guard let bundleAssoDBPath = Bundle.main.path(forResource: "extraAsso", ofType: "db") else {
                print("在 Bundle 中找不到關聯字資料庫檔案")
                return
            }
        
        // 獲取臨時目錄路徑
        let tempDirectory = NSTemporaryDirectory()
        let destinationPath = tempDirectory + "liu.db"
        let assoDestinationPath = tempDirectory + "extraAsso.db"
        
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
        
        do {
                // 如果檔案已存在，先移除
                if FileManager.default.fileExists(atPath: assoDestinationPath) {
                    try FileManager.default.removeItem(atPath: assoDestinationPath)
                }
                
                // 複製資料庫到臨時目錄
                try FileManager.default.copyItem(atPath: bundleAssoDBPath, toPath: assoDestinationPath)
                print("關聯字資料庫已複製到: \(assoDestinationPath)")
                
                // 打開複製的關聯字資料庫
                assoDB = FMDatabase(path: assoDestinationPath)
                if assoDB?.open() == true {
                    print("成功開啟關聯字資料庫，路徑: \(assoDestinationPath)")
                    
                    // 禁用 WAL 模式
                    if assoDB?.executeUpdate("PRAGMA journal_mode=DELETE", withArgumentsIn: []) == true {
                        print("已設定關聯字資料庫為標準 journal 模式")
                    }
                } else {
                    print("開啟關聯字資料庫失敗: \(assoDB?.lastErrorMessage() ?? "未知錯誤")")
                }
            } catch {
                print("處理關聯字資料庫失敗: \(error)")
            }
    }
    
    // 查詢關聯字方法
    func lookupAssociatedChars(_ previousChar: String, limit: Int = 5) -> [String] {
        let startTime = CFAbsoluteTimeGetCurrent()
        var results = [String]()
        
        // 先確保緩衝區已寫入
        if !assoCharBuffer.isEmpty {
            flushAssociatedCharBuffer()
        }
    
        // 如果資料庫還沒初始化完成，返回空結果
        guard let db = assoDB, db.isOpen else {
            print("關聯字資料庫未開啟或尚未初始化完成")
            return results
        }
        
        // 執行查詢
        let querySQL = "SELECT asso FROM AssoDB WHERE cw = ? ORDER BY dbtime DESC, freq DESC LIMIT ?"
        
        if let resultSet = db.executeQuery(querySQL, withArgumentsIn: [previousChar, limit]) {
            while resultSet.next() {
                if let associatedChar = resultSet.string(forColumn: "asso") {
                    results.append(associatedChar)
                }
            }
            resultSet.close()
        } else {
            print("查詢關聯字失敗: \(db.lastErrorMessage())")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("查詢字「\(previousChar)」的關聯字, 找到 \(results.count) 個, 耗時: \((endTime-startTime)*1000) ms")
        
        return results
    }
    
    // 緩衝關聯字方法
    func bufferAssociatedChar(previous: String, current: String) {
        // 避免非中文字符或特殊字符的關聯
        guard previous.count == 1 && current.count == 1 else { return }
        
        // 檢查前一字是否為英文（含大小寫）、數字或符號
        let englishCharsPattern = "^[A-Za-z0-9\\p{P}\\p{S}]$"
        let japanesePunctuation = """
        、。，．・：；？！～'"「」『』【】（）［］｛｝〈〉《》〔〕
        """

        let chinesePunctuation = """
        ，。、；：？！…—·''""〝〞‵′〃《》〈〉【】〖〗（）［］｛｝「」『』
        """
        let allPunctuation = japanesePunctuation + chinesePunctuation
        
        // 1. 檢查前一字是否為英文、數字或標點符號
        if let regex = try? NSRegularExpression(pattern: englishCharsPattern, options: []) {
            let range = NSRange(location: 0, length: previous.utf16.count)
            if regex.firstMatch(in: previous, options: [], range: range) != nil {
                print("前一字 '\(previous)' 是英文、數字或西文符號，不記錄關聯")
                return
            }
        }
        
        // 2. 檢查前一字是否為中文或日文標點符號
        if allPunctuation.contains(previous) {
            print("前一字 '\(previous)' 是中文或日文標點符號，不記錄關聯")
            return
        }
        
        // 3. 檢查前一字是否為日文字符
        // 日文平假名：U+3040..U+309F
        // 日文片假名：U+30A0..U+30FF
        if let unicodeScalar = previous.unicodeScalars.first {
            let value = unicodeScalar.value
            if (0x3040...0x309F).contains(value) || (0x30A0...0x30FF).contains(value) {
                print("前一字 '\(previous)' 是日文字符，不記錄關聯")
                return
            }
        }
        
        // 通過所有過濾條件後，將關聯對加入緩衝區
        assoCharBuffer.append((previous: previous, current: current))
        
        // 檢查是否應該執行寫入
        let currentTime = Date().timeIntervalSince1970
        if assoCharBuffer.count >= 10 || (currentTime - lastAssoWriteTime > assoWriteInterval) {
            flushAssociatedCharBuffer()
        }
    }
    
    
    // 寫入關聯字緩衝區方法
    func flushAssociatedCharBuffer() {
        guard !assoCharBuffer.isEmpty, let db = assoDB, db.isOpen else { return }
        
        // 使用交易來提高效率
        if db.beginTransaction() {
            // 獲取當前時間並格式化為指定格式
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm"
            let formattedDate = dateFormatter.string(from: Date())
            
            for item in assoCharBuffer {
                // 嘗試更新現有記錄
                let updateSQL = """
                UPDATE AssoDB 
                SET freq = freq + 1, dbtime = ? 
                WHERE cw = ? AND asso = ?
                """
                
                if db.executeUpdate(updateSQL, withArgumentsIn: [formattedDate, item.previous, item.current]) {
                    // 檢查是否有記錄被更新
                    if db.changes == 0 {
                        // 無記錄被更新，插入新記錄
                        let insertSQL = """
                        INSERT INTO AssoDB (cw, asso, freq, dbtime)
                        VALUES (?, ?, 1, ?)
                        """
                        
                        if !db.executeUpdate(insertSQL, withArgumentsIn: [item.previous, item.current, formattedDate]) {
                            print("插入關聯字失敗: \(db.lastErrorMessage())")
                        }
                    }
                } else {
                    print("更新關聯字失敗: \(db.lastErrorMessage())")
                }
            }
            
            if db.commit() {
                print("成功更新 \(assoCharBuffer.count) 個關聯字記錄")
                assoCharBuffer.removeAll()
                lastAssoWriteTime = Date().timeIntervalSince1970
            } else {
                print("提交關聯字更新失敗: \(db.lastErrorMessage())")
            }
        }
    }
    
    func cleanupOldAssociatedChars() {
        guard let db = assoDB, db.isOpen else { return }
        
        // 獲取 30 天前的日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH-mm"
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let cutoffDate = dateFormatter.string(from: thirtyDaysAgo)
        
        // 刪除使用頻率低於 3 且超過 30 天未使用的關聯字
        let cleanupSQL = """
        DELETE FROM AssoDB
        WHERE freq < 3 AND dbtime < ?
        """
        
        if db.executeUpdate(cleanupSQL, withArgumentsIn: [cutoffDate]) {
            let deleted = db.changes
            if deleted > 0 {
                print("已清理 \(deleted) 個不常用的關聯字記錄")
            }
        } else {
            print("清理舊關聯字記錄失敗: \(db.lastErrorMessage())")
        }
    }
    
    // 顯示關聯字的方法
    func displayAssociatedChars(_ associatedChars: [String]) {
        // 清除現有的候選字按鈕
        for button in candidateButtons {
            button.removeFromSuperview()
        }
        candidateButtons.removeAll()
        
        // 移除舊的視圖（除了輸入標籤）
        for subview in candidateView.subviews {
            if subview != inputCodeLabel {
                subview.removeFromSuperview()
            }
        }
        
        // 如果沒有關聯字，不顯示
        if associatedChars.isEmpty {
            return
        }
        
        // 創建關聯字標籤
        let assoLabel = UILabel()
        assoLabel.text = "▶"  // 使用箭頭表示關聯字
        assoLabel.textColor = UIColor.systemBlue
        assoLabel.font = UIFont.systemFont(ofSize: keyboardMetrics.subtitleFontSize)
        assoLabel.translatesAutoresizingMaskIntoConstraints = false
        candidateView.addSubview(assoLabel)
        
        // 設置標籤約束
        NSLayoutConstraint.activate([
            assoLabel.leadingAnchor.constraint(equalTo: candidateView.leadingAnchor, constant: 10),
            assoLabel.centerYAnchor.constraint(equalTo: candidateView.centerYAnchor)
        ])
        
        // 創建關聯字堆疊視圖
        let assoStackView = UIStackView()
        assoStackView.axis = .horizontal
        assoStackView.spacing = 5
        assoStackView.alignment = .center
        assoStackView.translatesAutoresizingMaskIntoConstraints = false
        candidateView.addSubview(assoStackView)
        
        // 設置堆疊視圖約束
        NSLayoutConstraint.activate([
            assoStackView.centerYAnchor.constraint(equalTo: candidateView.centerYAnchor),
            assoStackView.leadingAnchor.constraint(equalTo: assoLabel.trailingAnchor, constant: 5)
        ])
        
        // 依序添加關聯字按鈕
        for (index, assoChar) in associatedChars.enumerated() {
            let button = createCandidateButton(for: assoChar, at: index)
            button.backgroundColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)  // 淺藍色背景，區分關聯字
            assoStackView.addArrangedSubview(button)
            candidateButtons.append(button)
        }
        
        // 設置堆疊視圖的尾部約束
        if let lastButton = candidateButtons.last {
            lastButton.trailingAnchor.constraint(equalTo: candidateView.contentLayoutGuide.trailingAnchor, constant: -10).isActive = true
        }
        
        // 更新佈局以計算內容尺寸
        candidateView.layoutIfNeeded()
        
        // 設置滾動視圖的內容尺寸
        let stackWidth = assoStackView.frame.width
        let totalWidth = assoLabel.frame.width + 15 + stackWidth
        candidateView.contentSize = CGSize(width: max(totalWidth, candidateView.frame.width), height: candidateView.frame.height)
    }
    
    
    
    
    // 生命週期方法
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 初始化鍵盤尺寸參數
        keyboardMetrics = KeyboardMetrics(deviceState: getCurrentDeviceState())
        
        // 設置基本視圖框架
        setupViews()
        
        // 設置鍵盤總高度
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: keyboardMetrics.keyboardHeight)
        heightConstraint.priority = .defaultHigh // 使用高優先級但非必須
        heightConstraint.isActive = true
    
        // 設置嘸蝦米模式
        isBoshiamyMode = true
        
        // 添加方向變化通知監聽
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidResize),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // 確保在視圖加載後創建鍵盤按鈕
        DispatchQueue.main.async {
            // 強制創建鍵盤，而不是等待 viewDidLayoutSubviews
            self.setupKeyboardLayout()
            
            // 設置長按手勢
            self.setupLongPressGestures()
        }
        
        // 非同步初始化資料庫和載入注音資料
        DispatchQueue.global(qos: .userInitiated).async {
            self.initDatabase()
            
            DispatchQueue.global(qos: .utility).async {
                self.loadBopomofoData()
            }
        }
        
        DispatchQueue.global(qos: .utility).async {
            self.cleanupOldAssociatedChars()
        }
    }
    
    // 添加視圖大小變化的處理方法
    @objc func screenDidResize() {
        // 使用畫面大小判斷方向
        let currentState = getCurrentDeviceState()
        
        // 檢查是否真的發生了狀態變化
        if currentState != keyboardMetrics.deviceState {
            print("畫面大小變化偵測到狀態改變: \(keyboardMetrics.deviceState) -> \(currentState)")
            
            // 更新鍵盤尺寸參數
            keyboardMetrics = KeyboardMetrics(deviceState: currentState)
            
            // 應用新的尺寸參數
            applyKeyboardMetrics()
            
            // 重新創建鍵盤
            recreateKeyboard()
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
        for (rowIndex, rowButtons) in keyButtons.enumerated() {
            for (colIndex, button) in rowButtons.enumerated() {
                // 選擇當前布局和次要標籤
                let currentLayout: [[String]]
                let currentSecondaryLabels: [[String]]
                
                if isSymbolMode {
                    currentLayout = symbolRows
                    currentSecondaryLabels = symbolSecondaryLabels
                } else {
                    currentLayout = isBoshiamyMode ? boshiamySymbols : keyboardRows
                    currentSecondaryLabels = isBoshiamyMode ? boshiamySecondaryLabels : secondaryLabels
                }
                
                // 確保索引有效
                if rowIndex < currentLayout.count && colIndex < currentLayout[rowIndex].count &&
                   rowIndex < currentSecondaryLabels.count && colIndex < currentSecondaryLabels[rowIndex].count {
                    
                    let keyTitle = currentLayout[rowIndex][colIndex]
                    let secondaryText = currentSecondaryLabels[rowIndex][colIndex]
                    
                    // 跳過特殊按鍵
                    if keyTitle.contains("中") || keyTitle.contains("英") || keyTitle.contains("space") ||
                       keyTitle.contains("空白鍵") || keyTitle.contains("shift") || keyTitle.contains("⇧") ||
                       keyTitle.contains("dismiss") || keyTitle.contains("⌄") || keyTitle.contains("delete") ||
                       keyTitle.contains("⌫") || keyTitle.contains("return") || keyTitle.contains("⏎") ||
                       keyTitle.contains("🌐") || keyTitle.contains("英/中") || keyTitle == "符" || keyTitle == "ABC" {
                        continue
                    }
                    
                    // 只在有次要標籤時添加長按手勢
                    if !secondaryText.isEmpty {
                        // 添加長按手勢
                        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
                        longPress.minimumPressDuration = 0.4 // 增加到0.4秒，避免太敏感
                        longPress.cancelsTouchesInView = true
                        
                        // 設置長按手勢的優先級高於點擊
                        longPress.delegate = self
                        
                        button.addGestureRecognizer(longPress)
                        //print("為按鍵 \(keyTitle) 添加長按手勢，次要標籤: \(secondaryText)")
                    }
                }
            }
        }
    }
    
    // 處理長按事件
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        // 只在手勢開始時處理一次，避免重複處理
        if gesture.state == .began, let button = gesture.view as? UIButton {
            print("長按事件觸發")
            
            // 取得按鈕的行列索引
            let row = button.tag / 100
            let col = button.tag % 100
            
            // 選擇當前布局和次要標籤
            let currentLayout: [[String]]
            let currentSecondaryLabels: [[String]]
            
            if isSymbolMode {
                currentLayout = symbolRows
                currentSecondaryLabels = symbolSecondaryLabels
            } else {
                currentLayout = isBoshiamyMode ? boshiamySymbols : keyboardRows
                currentSecondaryLabels = isBoshiamyMode ? boshiamySecondaryLabels : secondaryLabels
            }
            
            // 確保索引有效
            if row < currentLayout.count && col < currentLayout[row].count &&
               row < currentSecondaryLabels.count && col < currentSecondaryLabels[row].count {
                
                let secondaryText = currentSecondaryLabels[row][col]
                
                if !secondaryText.isEmpty {
                    // 提供視覺反饋
                    animateButton(button)
                    
                    // 延遲執行文字輸入，確保動畫效果先顯示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if self.isBoshiamyMode {
                            // 嘸蝦米模式下，直接輸入次要標籤對應的字符
                            self.textDocumentProxy.insertText(secondaryText)
                        } else {
                            // 英文模式下，如果是字母則輸入大寫
                            let key = currentLayout[row][col]
                            if key.count == 1 && key >= "a" && key <= "z" {
                                self.textDocumentProxy.insertText(key.uppercased())
                            } else {
                                // 非字母按鍵則輸入次要標籤字符
                                self.textDocumentProxy.insertText(secondaryText)
                            }
                        }
                        print("長按輸入: \(secondaryText)")
                    }
                }
            }
        }
    }
    
    // 使用Auto Layout設置視圖
    private func setupViews() {
        // 創建頂部容器視圖 (候選區)
        let candidateContainer = UIView()
        candidateContainer.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        candidateContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(candidateContainer)
        
        // 創建鍵盤視圖
        keyboardView = UIView()
        keyboardView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        
        // 主要佈局約束
        NSLayoutConstraint.activate([
            // 候選區約束
            candidateContainer.topAnchor.constraint(equalTo: view.topAnchor),
            candidateContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // 鍵盤區約束
            keyboardView.topAnchor.constraint(equalTo: candidateContainer.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 保存候選區高度約束
        candidateViewHeightConstraint = candidateContainer.heightAnchor.constraint(
            equalToConstant: keyboardMetrics.candidateViewHeight)
        candidateViewHeightConstraint.priority = .defaultHigh  // 設置優先級
        candidateViewHeightConstraint.isActive = true
        
        // 創建左側回車按鈕
        let enterButton = UIButton(type: .system)
        enterButton.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        enterButton.setTitle("⏎", for: .normal)
        enterButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        enterButton.layer.cornerRadius = 4
        enterButton.layer.borderWidth = 0.5
        enterButton.layer.borderColor = UIColor.darkGray.cgColor
        enterButton.tag = 3001
        enterButton.addTarget(self, action: #selector(candidateAreaButtonPressed(_:)), for: .touchUpInside)
        enterButton.translatesAutoresizingMaskIntoConstraints = false
        candidateContainer.addSubview(enterButton)
        
        // 創建右側刪除按鈕
        let backspaceButton = UIButton(type: .system)
        backspaceButton.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        backspaceButton.setTitle("⌫", for: .normal)
        backspaceButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        backspaceButton.layer.cornerRadius = 4
        backspaceButton.layer.borderWidth = 0.5
        backspaceButton.layer.borderColor = UIColor.darkGray.cgColor
        backspaceButton.tag = 3000
        backspaceButton.addTarget(self, action: #selector(candidateAreaButtonPressed(_:)), for: .touchUpInside)
        backspaceButton.translatesAutoresizingMaskIntoConstraints = false
        
        
        // 添加長按刪除手勢
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressDelete(_:)))
        longPress.minimumPressDuration = 0.5
        backspaceButton.addGestureRecognizer(longPress)
        candidateContainer.addSubview(backspaceButton)
        
        // 創建候選字滾動視圖
        candidateView = UIScrollView()
        candidateView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        candidateView.translatesAutoresizingMaskIntoConstraints = false
        candidateView.isScrollEnabled = true
        candidateView.showsHorizontalScrollIndicator = false
        candidateView.showsVerticalScrollIndicator = false
        candidateView.bounces = true
        candidateView.alwaysBounceHorizontal = true
        candidateContainer.addSubview(candidateView)
        
        // 創建輸入碼標籤
        inputCodeLabel = UILabel()
        inputCodeLabel.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        inputCodeLabel.textColor = UIColor.darkGray
        inputCodeLabel.font = UIFont.systemFont(ofSize: keyboardMetrics.subtitleFontSize)
        inputCodeLabel.textAlignment = .center
        inputCodeLabel.translatesAutoresizingMaskIntoConstraints = false
        candidateView.addSubview(inputCodeLabel)
        
        // 設置側邊按鈕和候選區的約束
        let sideBtnWidth: CGFloat = isIPhone ? 60 : 100
        
        NSLayoutConstraint.activate([
            // 左側按鈕約束
            enterButton.leadingAnchor.constraint(equalTo: candidateContainer.leadingAnchor, constant: 2),
            enterButton.centerYAnchor.constraint(equalTo: candidateContainer.centerYAnchor),
            enterButton.widthAnchor.constraint(equalToConstant: sideBtnWidth),
            enterButton.heightAnchor.constraint(equalTo: candidateContainer.heightAnchor, constant: -4),
            
            // 右側按鈕約束
            backspaceButton.trailingAnchor.constraint(equalTo: candidateContainer.trailingAnchor, constant: -2),
            backspaceButton.centerYAnchor.constraint(equalTo: candidateContainer.centerYAnchor),
            backspaceButton.widthAnchor.constraint(equalToConstant: sideBtnWidth),
            backspaceButton.heightAnchor.constraint(equalTo: candidateContainer.heightAnchor, constant: -4),
            
            // 候選字滾動視圖約束
            candidateView.leadingAnchor.constraint(equalTo: enterButton.trailingAnchor, constant: 4),
            candidateView.trailingAnchor.constraint(equalTo: backspaceButton.leadingAnchor, constant: -4),
            candidateView.topAnchor.constraint(equalTo: candidateContainer.topAnchor),
            candidateView.bottomAnchor.constraint(equalTo: candidateContainer.bottomAnchor),
            
            // 輸入碼標籤約束
            inputCodeLabel.topAnchor.constraint(equalTo: candidateView.topAnchor, constant: 4),
            inputCodeLabel.leadingAnchor.constraint(equalTo: candidateView.leadingAnchor, constant: 4),
            inputCodeLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // 初始化狀態
        updateInputCodeDisplay("")
        displayCandidates([])
    }

    // 添加候選區域按鈕點擊處理方法
    @objc func candidateAreaButtonPressed(_ sender: UIButton) {
        animateButton(sender)
        
        let tag = sender.tag
        
        if tag == 3000 {  // Backspace 按鈕
            // 執行刪除操作
            handleDeleteAction()
        } else if tag == 3001 {  // Enter 按鈕
            // 執行回車操作
            textDocumentProxy.insertText("\n")
        }
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
        
        // 每次佈局變化時檢查設備狀態
        let currentState = getCurrentDeviceState()
        
        // 檢查是否發生了狀態變化
        if currentState != keyboardMetrics.deviceState {
            print("佈局變化偵測到狀態改變: \(keyboardMetrics.deviceState) -> \(currentState)")
            
            // 更新鍵盤尺寸參數
            keyboardMetrics = KeyboardMetrics(deviceState: currentState)
            
            // 應用新的尺寸參數
            applyKeyboardMetrics()
            
            // 重新創建鍵盤
            recreateKeyboard()
        } else if keyButtons.isEmpty {
            // 如果按鈕尚未創建（初次加載），立即創建
            print("按鈕尚未創建，立即創建鍵盤")
            setupKeyboardLayout()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // 確定新的設備狀態
        let isLandscape = size.width > size.height
        let newState: DeviceState = isIPhone ?
            (isLandscape ? .iPhoneLandscape : .iPhonePortrait) :
            (isLandscape ? .iPadLandscape : .iPadPortrait)
        
        print("轉變至狀態: \(newState), 按鍵高度將為: \(KeyboardMetrics(deviceState: newState).keyHeight), 候選區高度將為: \(KeyboardMetrics(deviceState: newState).candidateViewHeight)")
        
        // 使用 coordinator 進行動畫過渡
        coordinator.animate(alongsideTransition: { _ in
            // 更新 keyboardMetrics
            self.keyboardMetrics = KeyboardMetrics(deviceState: newState)
            
            // 立即更新候選區高度約束
            self.candidateViewHeightConstraint.constant = self.keyboardMetrics.candidateViewHeight
            
            // 觸發佈局更新
            self.view.setNeedsLayout()
        }, completion: { _ in
            // 動畫完成後，重新創建鍵盤以確保正確的佈局
            self.recreateKeyboard()
        })
    }
    
    // 監聽裝置方向變化
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // 檢查水平和垂直尺寸類別是否有變化
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass ||
           traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass {
            
            screenDidResize()
        }
    }
    
    @objc func keyPressed(_ sender: UIButton) {
        // 檢查是否由長按手勢觸發，如果是則不處理按一下事件
        if isTriggeredByLongPress(sender) {
            print("長按狀態中，忽略點擊事件")
            return
        }
        
        // 獲取按鍵資訊
        let row = sender.tag / 100
        let col = sender.tag % 100
        
        // 選擇當前布局
        let currentLayout: [[String]]
        if isSymbolMode {
            currentLayout = symbolRows
        } else {
            currentLayout = isBoshiamyMode ? boshiamySymbols : keyboardRows
        }
        
        // 確保索引有效
        guard row < currentLayout.count && col < currentLayout[row].count else {
            print("無效的按鍵索引: row \(row), col \(col)")
            return
        }
        
        let key = currentLayout[row][col]
        
        // 按鍵視覺反饋
        animateButton(sender)
        
        // 處理特殊情況
        if key == "、" && isBoshiamyMode {
            startHomophoneLookup()
            return
        }
        
        // 處理同音字反查模式下的按鍵
        if isHomophoneLookupMode {
            handleHomophoneLookupKeyPress(key)
            return
        }
        
        // 處理按鍵類型
        handleKeyType(key)
    }

    // 檢查是否由長按觸發
    private func isTriggeredByLongPress(_ button: UIButton) -> Bool {
        // 檢查按鈕是否有長按手勢，且手勢是否正在進行中
        for recognizer in button.gestureRecognizers ?? [] {
            if let longPress = recognizer as? UILongPressGestureRecognizer {
                if longPress.state == .began || longPress.state == .changed {
                    print("檢測到長按手勢進行中")
                    return true
                }
            }
        }
        return false
    }

    // 處理按鍵類型
    private func handleKeyType(_ key: String) {
        // 輸入模式切換
        if key.contains("中") || key.contains("英") {
            toggleInputMode()
        }
        // 符號模式切換
        else if key == "符" {
            toggleSymbolMode()
        }
        // 從符號模式返回
        else if key == "ABC" {
            isSymbolMode = false
            recreateKeyboard()
        }
        // 空格鍵
        else if key.contains("space") || key.contains("空白鍵") || key.contains("  　") {
            handleSpaceKey()
        }
        // Shift鍵
        else if key.contains("shift") || key.contains("⇧") {
            toggleShift()
        }
        // 切換鍵盤
        else if key.contains("🌐") || key.contains("⌄") {
            dismissKeyboard()
        }
        // 刪除鍵
        else if key.contains("delete") || key.contains("⌫") {
            handleDeleteKey()
        }
        // 回車鍵
        else if key.contains("return") || key.contains("⏎") {
            textDocumentProxy.insertText("\n")
        }
        // 一般按鍵
        else {
            handleRegularKey(key)
        }
    }

    // 處理空格鍵
    private func handleSpaceKey() {
        if isBoshiamyMode && !collectedRoots.isEmpty {
            if !candidateButtons.isEmpty, let firstCandidateButton = candidateButtons.first {
                candidateSelected(firstCandidateButton)
            } else {
                collectedRoots = ""
                updateInputCodeDisplay("")
                displayCandidates([])
            }
        } else {
            textDocumentProxy.insertText(" ")
        }
    }

    // 處理刪除鍵
    private func handleDeleteKey() {
        handleDeleteAction()
    }

    // 處理一般按鍵
    private func handleRegularKey(_ key: String) {
        if isSymbolMode {
            textDocumentProxy.insertText(key)
        } else if isBoshiamyMode {
            let cleanKey = key.components(separatedBy: " ").first ?? key
            handleBoshiamyInput(cleanKey)
        } else {
            handleEnglishInput(key)
        }
    }

    // 處理英文輸入
    private func handleEnglishInput(_ key: String) {
        let inputChar = key.first.map(String.init) ?? ""
        let inputText = isShifted && inputChar.count == 1 && (inputChar >= "a" && inputChar <= "z") ?
            inputChar.uppercased() : inputChar
        
        textDocumentProxy.insertText(inputText)
        
        // 臨時大寫後重置
        if isShifted && !isShiftLocked {
            isShifted = false
            updateShiftButtonAppearance()
            updateLetterKeysForShiftState()
        }
    }

    
    // 更新 Shift 按鈕外觀
    func updateShiftButtonAppearance() {
        // 獲取正確的布局
        let layout = keyboardRows
        let skipNumberRow = (keyboardMetrics.deviceState == .iPhonePortrait || keyboardMetrics.deviceState == .iPhoneLandscape) && !isSymbolMode
        
        // 查找Shift鍵
        for (displayRowIndex, rowButtons) in keyButtons.enumerated() {
            // 計算對應的實際行索引，考慮是否跳過了數字行
            let actualRowIndex = skipNumberRow ? displayRowIndex + 1 : displayRowIndex
            
            for (keyIndex, button) in rowButtons.enumerated() {
                if actualRowIndex < layout.count && keyIndex < layout[actualRowIndex].count {
                    let key = layout[actualRowIndex][keyIndex]
                    if key.contains("shift") || key.contains("⇧") {
                        print("找到Shift鍵：行\(displayRowIndex)，列\(keyIndex)")
                        
                        if var config = button.configuration {
                            if isShifted {
                                if isShiftLocked {
                                    // 鎖定大寫
                                    config.background.backgroundColor = UIColor.darkGray
                                    config.baseForegroundColor = UIColor.systemBlue
                                } else {
                                    // 臨時大寫
                                    config.background.backgroundColor = UIColor.lightGray
                                    config.baseForegroundColor = UIColor.black
                                }
                            } else {
                                // 正常狀態
                                config.background.backgroundColor = UIColor.white
                                config.baseForegroundColor = UIColor.black
                            }
                            button.configuration = config
                        }
                    }
                }
            }
        }
    }
    
    // 根據 Shift 狀態更新字母按鍵顯示
    func updateLetterKeysForShiftState() {
        let layout = keyboardRows
        let skipNumberRow = (keyboardMetrics.deviceState == .iPhonePortrait || keyboardMetrics.deviceState == .iPhoneLandscape) && !isSymbolMode
        
        for (displayRowIndex, rowButtons) in keyButtons.enumerated() {
            // 計算對應的實際行索引，考慮是否跳過了數字行
            let actualRowIndex = skipNumberRow ? displayRowIndex + 1 : displayRowIndex
            
            for (keyIndex, button) in rowButtons.enumerated() {
                if actualRowIndex < layout.count && keyIndex < layout[actualRowIndex].count {
                    let key = layout[actualRowIndex][keyIndex]
                    if key.count == 1 && key >= "a" && key <= "z" {
                        let newKey = isShifted ? key.uppercased() : key
                        button.setTitle(newKey, for: .normal)
                    }
                }
            }
        }
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
        // 如果目前是符號模式，切換到上一個模式（保持原有英/中狀態）
        if isSymbolMode {
            isSymbolMode = false
            recreateKeyboard()
            return
        }
        
        // 否則正常切換中英文模式
        isBoshiamyMode = !isBoshiamyMode
        
        // 清空已收集的字根和候選字
        collectedRoots = ""
        updateInputCodeDisplay("")
        displayCandidates([])
        
        // 顯示當前模式的提示
        let modeText = isBoshiamyMode ? "嘸蝦米模式" : "英文模式"
        print("切換到\(modeText)")
        
        // 重新建立鍵盤按鍵
        recreateKeyboard()
        
        // 重新設置長按手勢
        DispatchQueue.main.async {
            self.setupLongPressGestures()
        }
    }

    // 3. 新增切換符號模式方法
    func toggleSymbolMode() {
        isSymbolMode = !isSymbolMode
        
        // 清空已收集的字根和候選字
        collectedRoots = ""
        updateInputCodeDisplay("")
        displayCandidates([])
        
        // 顯示當前模式的提示
        let modeText = isSymbolMode ? "符號模式" : (isBoshiamyMode ? "嘸蝦米模式" : "英文模式")
        print("切換到\(modeText)")
        
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
        keyboardView.subviews.forEach { $0.removeFromSuperview() }
        keyButtons.removeAll()
        
        // 更新佈局
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // 重新創建按鍵
        setupKeyboardLayout()
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
        
        // 移除舊的視圖（除了輸入標籤）
        for subview in candidateView.subviews {
            if subview != inputCodeLabel {
                subview.removeFromSuperview()
            }
        }
        
        // 如果沒有候選字，只顯示輸入字碼
        if candidates.isEmpty {
            // 不需要調整高度，因為高度已經固定為50
            return
        }
        
        // 創建候選字堆疊視圖 - 水平排列
        let candidatesStackView = UIStackView()
        candidatesStackView.axis = .horizontal
        candidatesStackView.spacing = 5
        candidatesStackView.alignment = .center
        candidatesStackView.translatesAutoresizingMaskIntoConstraints = false
        candidateView.addSubview(candidatesStackView)
        
        // 設置候選字堆疊視圖約束
        NSLayoutConstraint.activate([
            candidatesStackView.centerYAnchor.constraint(equalTo: candidateView.centerYAnchor),
            candidatesStackView.leadingAnchor.constraint(equalTo: inputCodeLabel.trailingAnchor, constant: 10)
            // 不設置trailing約束，允許超出滾動
        ])
        
        // 依序添加候選字按鈕
        for (index, candidate) in candidates.enumerated() {
            let button = createCandidateButton(for: candidate, at: index)
            candidatesStackView.addArrangedSubview(button)
            candidateButtons.append(button)
        }
        
        // 設置堆疊視圖的尾部約束，確保內容寬度足夠
        if let lastButton = candidateButtons.last {
            lastButton.trailingAnchor.constraint(equalTo: candidateView.contentLayoutGuide.trailingAnchor, constant: -10).isActive = true
        }
        
        // 更新佈局以計算內容尺寸
        candidateView.layoutIfNeeded()
        
        // 設置滾動視圖的內容尺寸
        let stackWidth = candidatesStackView.frame.width
        let totalWidth = inputCodeLabel.frame.width + 10 + stackWidth
        candidateView.contentSize = CGSize(width: max(totalWidth, candidateView.frame.width), height: candidateView.frame.height)
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
           // 獲取前一個字符
           var previousChar = ""
           if let contextBefore = textDocumentProxy.documentContextBeforeInput,
              let lastChar = contextBefore.last {
               previousChar = String(lastChar)
           }
           
           // 輸入選中的字詞
           textDocumentProxy.insertText(candidate)
           
           // 記錄關聯字 (如果有前一個字符，且都是單字)
           if !previousChar.isEmpty && candidate.count == 1 {
               bufferAssociatedChar(previous: previousChar, current: candidate)
           }
           
           // 無論是否顯示關聯字，都清空已收集的字根
           collectedRoots = ""
           updateInputCodeDisplay("")
           
           // 查詢並顯示關聯字 (如果輸入的是單字)
           if candidate.count == 1 {
               let associatedChars = lookupAssociatedChars(candidate)
               if !associatedChars.isEmpty {
                   displayAssociatedChars(associatedChars)
                   return  // 提前返回，不清空候選字區域
               }
           }
           
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
    // 5. 修改 setupKeyboardLayout 方法，根據設備類型調整鍵盤佈局
    private func setupKeyboardLayout() {
        // 清除現有按鍵
        keyboardView.subviews.forEach { $0.removeFromSuperview() }
        keyButtons.removeAll()
        
        // 選擇當前佈局
        let currentLayout: [[String]]
        let currentSecondaryLabels: [[String]]
        
        if isSymbolMode {
            currentLayout = symbolRows
            currentSecondaryLabels = symbolSecondaryLabels
        } else {
            currentLayout = isBoshiamyMode ? boshiamySymbols : keyboardRows
            currentSecondaryLabels = isBoshiamyMode ? boshiamySecondaryLabels : secondaryLabels
        }
        
        // 建立主堆疊視圖
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fillEqually
        mainStackView.spacing = keyboardMetrics.rowSpacing
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(mainStackView)
        
        // 主堆疊視圖約束
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: keyboardMetrics.keyboardPadding),
            mainStackView.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: keyboardMetrics.keyboardPadding),
            mainStackView.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -keyboardMetrics.keyboardPadding),
            mainStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -keyboardMetrics.keyboardPadding)
        ])
        
        // 判斷是否跳過數字行
        let skipNumberRow = (keyboardMetrics.deviceState == .iPhonePortrait ||
                            keyboardMetrics.deviceState == .iPhoneLandscape) && !isSymbolMode
        
        // 創建所有行
        for (rowIndex, row) in currentLayout.enumerated() {
            // 跳過不需要的行
            if skipNumberRow && rowIndex == 0 {
                continue
            }
            
            // 檢查是否為最後一行（需要特殊處理）
            let isLastRow = rowIndex == currentLayout.count - 1
            
            // 創建行堆疊視圖
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.spacing = keyboardMetrics.buttonSpacing
            rowStackView.translatesAutoresizingMaskIntoConstraints = false
            
            // 設置分配方式
            if isLastRow {
                rowStackView.distribution = .fill
            } else {
                rowStackView.distribution = .fillEqually
            }
            
            var rowButtons = [UIButton]()
            
            // 創建每一行的按鈕
            for (keyIndex, keyTitle) in row.enumerated() {
                let button = configureKeyButton(
                    keyTitle: keyTitle,
                    rowIndex: rowIndex,
                    keyIndex: keyIndex,
                    currentSecondaryLabels: currentSecondaryLabels
                )
                rowStackView.addArrangedSubview(button)
                rowButtons.append(button)
            }
            
            
            
            // 添加行到主堆疊視圖
            mainStackView.addArrangedSubview(rowStackView)
            keyButtons.append(rowButtons)
            
            // 使用異步調用最後一行寬度配置
            DispatchQueue.main.async {
               if let lastRow = self.keyButtons.last {
                   if let rowStackView = lastRow.first?.superview as? UIStackView {
                       self.configureLastRowWidthsAlternative(buttons: lastRow, rowStackView: rowStackView)
                   }
               }
            }
            
        }
        
        // 設置長按手勢
        DispatchQueue.main.async {
            self.setupLongPressGestures()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("重設最後一行")
        // 重新設置最後一行寬度
        if let lastRow = keyButtons.last, !lastRow.isEmpty,
           let rowStackView = lastRow.first?.superview as? UIStackView {
            configureLastRowWidthsAlternative(buttons: lastRow, rowStackView: rowStackView)
        }
    }
    
    // 專門用於配置最後一行按鈕寬度的方法
    private func configureLastRowWidthsAlternative(buttons: [UIButton], rowStackView: UIStackView) {
        // 移除 rowStackView 中的所有按鈕
        buttons.forEach { $0.removeFromSuperview() }
        
        // 清空 rowStackView
        rowStackView.subviews.forEach { $0.removeFromSuperview() }
        
        // 創建一個水平的容器視圖
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        rowStackView.addSubview(containerView)
        
        // 設置容器視圖的約束
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: rowStackView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: rowStackView.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: rowStackView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: rowStackView.trailingAnchor)
        ])
        
        // 定義不同的寬度比例
        let widthRatios: [CGFloat] = [0.125, 0.125, 0.5, 0.125, 0.125]
        
        // 計算間距的總寬度
        let totalSpacing = CGFloat(buttons.count - 1) * keyboardMetrics.buttonSpacing
        
        // 添加按鈕到容器視圖
        var lastRightAnchor = containerView.leadingAnchor
        
        for (index, button) in buttons.enumerated() {
            button.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(button)
            
            // 計算按鈕寬度
            let widthRatio = widthRatios[index]
            
            // 設置按鈕約束
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: containerView.topAnchor),
                button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                button.leadingAnchor.constraint(equalTo: lastRightAnchor, constant: index > 0 ? keyboardMetrics.buttonSpacing : 0),
                button.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: widthRatio, constant: -totalSpacing * widthRatio)
            ])
            
            // 更新最後一個右側錨點
            lastRightAnchor = button.trailingAnchor
        }
        
        // 確保最後一個按鈕的右側與容器右側對齊
        if let lastButton = buttons.last {
            lastButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        }
    }
    
    // 簡單修正 configureKeyButton 方法中的關鍵部分
    private func configureKeyButton(keyTitle: String, rowIndex: Int, keyIndex: Int, currentSecondaryLabels: [[String]]) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 4
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.darkGray.cgColor
        button.tag = rowIndex * 100 + keyIndex
        button.addTarget(self, action: #selector(keyPressed(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // 使用配置模式設置按鈕
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = UIColor.black
        config.background.backgroundColor = UIColor.white
        
        // 特殊按鍵使用不同背景色
        if keyTitle == "符" || keyTitle == "ABC" ||
           keyTitle.contains("中") || keyTitle.contains("英") ||
           keyTitle.contains("🌐") {
            config.background.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        }
        
        // 檢查是否有次要標籤
        let hasSecondaryLabel = rowIndex < currentSecondaryLabels.count &&
                               keyIndex < currentSecondaryLabels[rowIndex].count &&
                               !currentSecondaryLabels[rowIndex][keyIndex].isEmpty
        
        if hasSecondaryLabel {
            let secondaryText = currentSecondaryLabels[rowIndex][keyIndex]
            
            // 打印出來檢查實際值
            //print("配置按鍵: [\(rowIndex)][\(keyIndex)] 主標籤='\(keyTitle)' 次標籤='\(secondaryText)'")
            
            // 直接設置主要和次要標籤
            // 確保使用正確的值
            config.title = secondaryText
            config.subtitle = keyTitle
            
            config.titleAlignment = .center
            config.titlePadding = 2
            
            // 設置字體大小
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: self.keyboardMetrics.titleFontSize)
                outgoing.foregroundColor = UIColor.darkGray
                return outgoing
            }
            
            config.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: self.keyboardMetrics.subtitleFontSize)
                return outgoing
            }
        } else {
            // 沒有次要標籤
            config.title = keyTitle
            
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: self.keyboardMetrics.subtitleFontSize)
                return outgoing
            }
        }
        
        button.configuration = config
        return button
    }
    
    // 處理側欄按鍵點擊
    @objc func sideButtonPressed(_ sender: UIButton) {
        animateButton(sender)
        
        let tag = sender.tag
        
        // 處理backspace（左上或右上按鍵）
        if tag == 1000 || tag == 2000 {
            // 執行單擊刪除操作
            handleDeleteAction()
        } else if tag == 1001 || tag == 2001 {
            // enter - 左下或右下按鍵
            textDocumentProxy.insertText("\n")
        }
    }
    
    // 新增 - 處理長按刪除手勢
    @objc func handleLongPressDelete(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            isLongPressDeleteActive = true
            startDeleteTimer()
        } else if gesture.state == .ended || gesture.state == .cancelled {
            isLongPressDeleteActive = false
            stopDeleteTimer()
        }
    }

    // 新增 - 啟動刪除定時器
    private func startDeleteTimer() {
        stopDeleteTimer() // 先停止可能已存在的定時器
        deleteTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(timerDeleteAction), userInfo: nil, repeats: true)
    }

    // 簡化停止刪除定時器
    private func stopDeleteTimer() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }

    // 新增 - 定時器觸發的刪除操作
    @objc private func timerDeleteAction() {
        if isLongPressDeleteActive {
            handleDeleteAction(isLongPress: true)
        }
    }

    // 修改統一刪除操作的邏輯
    private func handleDeleteAction(isLongPress: Bool = false) {
        // 檢查當前文字內容，存儲可能被刪除的字符
        var deletedChar = ""
        var previousChar = ""
        
        if let currentText = textDocumentProxy.documentContextBeforeInput, currentText.count >= 1 {
            // 獲取將被刪除的字符
            if let lastIndex = currentText.index(currentText.endIndex, offsetBy: -1, limitedBy: currentText.startIndex) {
                deletedChar = String(currentText[lastIndex])
            }
            
            // 如果文字長度大於1，還需要獲取前一個字符
            if currentText.count >= 2,
               let prevIndex = currentText.index(currentText.endIndex, offsetBy: -2, limitedBy: currentText.startIndex) {
                previousChar = String(currentText[prevIndex])
            }
        }
        
        // 1. 如果在同音字反查模式，優先處理反查邏輯
        if isHomophoneLookupMode {
            handleDeleteInLookupMode(isLongPress: isLongPress)
            return
        }
        
        // 2. 如果在嘸蝦米模式並且有收集字根，處理字根刪除
        if isBoshiamyMode && !collectedRoots.isEmpty {
            // 刪除一個字根
            collectedRoots = String(collectedRoots.dropLast())
            
            // 更新輸入顯示
            updateInputCodeDisplay(collectedRoots)
            
            // 更新候選字
            if collectedRoots.isEmpty {
                displayCandidates([])
            } else {
                let candidates = lookupBoshiamyDictionary(collectedRoots)
                displayCandidates(candidates)
            }
        }
        // 3. 沒有字根或不在嘸蝦米模式，執行一般刪除
        else {
            textDocumentProxy.deleteBackward()
            
            // 清空候選字顯示
            displayCandidates([])
            
            // 檢查是否需要更新關聯字頻率
            if !deletedChar.isEmpty && !previousChar.isEmpty {
                decreaseAssociationFrequency(previous: previousChar, current: deletedChar)
            }
        }
        
        // 如果是長按操作，可以在這裡加入額外邏輯
        if isLongPress {
            // 長按刪除可能需要的額外邏輯
        }
    }
    
    // 減少關聯字頻率的方法
    func decreaseAssociationFrequency(previous: String, current: String) {
        // 避免處理非有效字符
        guard previous.count == 1 && current.count == 1 else { return }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self, let db = self.assoDB, db.isOpen else { return }
            
            // 先檢查該組關聯字是否存在
            let querySQL = "SELECT freq FROM AssoDB WHERE cw = ? AND asso = ?"
            
            do {
                if let resultSet = db.executeQuery(querySQL, withArgumentsIn: [previous, current]) {
                    if resultSet.next() {
                        let freq = resultSet.int(forColumn: "freq")
                        resultSet.close()
                        
                        // 根據頻率決定是減少還是刪除
                        if freq <= 1 {
                            // 頻率為1或更小，直接刪除該筆資料
                            // 直接執行刪除操作
                            let deleteSQL = "DELETE FROM AssoDB WHERE cw = ? AND asso = ?"
                            if db.executeUpdate(deleteSQL, withArgumentsIn: [previous, current]) {
                                print("已刪除關聯字對: \(previous)-\(current)")
                            }
                        } else {
                            // 頻率大於1，減少頻率
                            let updateSQL = "UPDATE AssoDB SET freq = freq - 3 WHERE cw = ? AND asso = ?"
                            if db.executeUpdate(updateSQL, withArgumentsIn: [previous, current]) {
                                print("已減少關聯字對 \(previous)-\(current) 的頻率")
                            } else {
                                print("減少關聯字頻率失敗: \(db.lastErrorMessage())")
                            }
                        }
                    } else {
                        // 關聯字對不存在
                        print("關聯字對 \(previous)-\(current) 不存在於資料庫")
                    }
                }
            } catch {
                print("檢查關聯字頻率時發生錯誤: \(error)")
            }
        }
    }
    
    // 在刪除資料庫中的關聯字時，也從緩衝區中移除
    func removeFromBuffer(previous: String, current: String) {
        assoCharBuffer.removeAll { pair in
            return pair.previous == previous && pair.current == current
        }
    }
    
    // 在刪除關聯字後，強制提交所有緩衝的操作
    func forceSyncDatabase() {
        // 強制寫入所有緩衝的關聯字
        flushAssociatedCharBuffer()
        
        // 確保資料庫同步
        if let db = assoDB, db.isOpen {
            db.executeUpdate("PRAGMA wal_checkpoint(FULL)", withArgumentsIn: [])
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
    // 在按需查詢字典時加入檢查
    func lookupBoshiamyDictionary(_ roots: String) -> [String] {
        let startTime = CFAbsoluteTimeGetCurrent()
        var results = [String]()
        
        // 如果資料庫還沒初始化完成，返回空結果
        guard let db = database, db.isOpen else {
            print("資料庫未開啟或尚未初始化完成")
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 保存緩衝區中的關聯字
        flushAssociatedCharBuffer()
    }
    
    deinit {
        // 關閉資料庫
        assoDB?.close()
        database?.close()
        
        // 移除通知觀察者
        NotificationCenter.default.removeObserver(self)
    }
    //------------同音字反查
    // 2. 加載注音數據的方法
    func loadBopomofoData() {
        print("開始載入注音資料...")
        
        // 為避免多執行緒問題，創建臨時字典
        var tempBopomofoDictionary: [String: [String]] = [:]
        var tempBopomospellDictionary: [String: [String]] = [:]
        
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
                            if tempBopomofoDictionary[character] == nil {
                                tempBopomofoDictionary[character] = [bopomofo]
                            } else {
                                tempBopomofoDictionary[character]?.append(bopomofo)
                            }
                        }
                    }
                }
                
                print("從bopomofo.csv載入了 \(tempBopomofoDictionary.count) 個字的注音")
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
                            if tempBopomospellDictionary[bopomofo] == nil {
                                tempBopomospellDictionary[bopomofo] = [character]
                            } else {
                                tempBopomospellDictionary[bopomofo]?.append(character)
                            }
                        }
                    }
                }
                
                print("從bopomospell.csv載入了 \(tempBopomospellDictionary.count) 個注音的同音字")
            } catch {
                print("讀取bopomospell.csv失敗: \(error)")
            }
        }
        
        // 在主執行緒更新實際使用的字典
        DispatchQueue.main.async {
            self.bopomofoDictionary = tempBopomofoDictionary
            self.bopomospellDictionary = tempBopomospellDictionary
            print("注音資料載入完成並應用")
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
            if key.contains("space") || key.contains("空白鍵") || key.contains("  　") {
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
               if collectedRoots.isEmpty {
               // 当处于同音字反查模式但未输入字根时，按空格键输出「、」字符
                   textDocumentProxy.insertText("、")
                   exitHomophoneLookupMode() // 输入后退出反查模式
               } else if !candidateButtons.isEmpty {
                   // 有字根和候选字时，选择第一个候选字
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
    private func handleDeleteInLookupMode(isLongPress: Bool = false) {
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
            
        default:
            // 未知階段，退出反查模式
            exitHomophoneLookupMode()
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
extension KeyboardViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 不允許同時識別多個手勢
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 確保觸摸開始時記錄相關信息
        return true
    }
}
