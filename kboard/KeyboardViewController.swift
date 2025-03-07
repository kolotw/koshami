import UIKit
import FMDB

class KeyboardViewController: UIInputViewController {
    enum DeviceState {
        case iPhonePortrait
        case iPhoneLandscape
        case iPadPortrait
        case iPadLandscape
    }
    var isLandscapeMode: Bool {
        return keyboardMetrics.deviceState == .iPhoneLandscape || keyboardMetrics.deviceState == .iPadLandscape
    }
    
    var isPhonePortraitMode: Bool {
        return keyboardMetrics.deviceState == .iPhonePortrait
    }
    struct KeyboardMetrics {
        // 當前裝置狀態
        var deviceState: DeviceState
        
        // 字體大小
        var titleFontSize: CGFloat
        var subtitleFontSize: CGFloat
        
        // 間距和邊距
        var buttonSpacing: CGFloat
        var rowSpacing: CGFloat
        var keyboardPadding: CGFloat
        
        // 按鈕尺寸
        var keyHeight: CGFloat
        var sideColumnWidth: CGFloat
        
        // 候選區高度
        var candidateViewHeight: CGFloat
        
        // 最後一行按鈕比例
        var functionKeyWidthRatio: CGFloat
        
        // 根據裝置狀態初始化所有參數
        init(deviceState: DeviceState) {
            self.deviceState = deviceState
            
            // 根據狀態設置所有參數
            switch deviceState {
            case .iPhonePortrait:
                titleFontSize = 8
                subtitleFontSize = 14
                buttonSpacing = 3
                rowSpacing = 4
                keyboardPadding = 3
                keyHeight = 80
                sideColumnWidth = 40
                candidateViewHeight = 100
                functionKeyWidthRatio = 0.12
                
            case .iPhoneLandscape:
                titleFontSize = 10
                subtitleFontSize = 16
                buttonSpacing = 4
                rowSpacing = 4
                keyboardPadding = 6
                keyHeight = 25  // 從 65 降低到 45
                sideColumnWidth = 50
                candidateViewHeight = 50
                functionKeyWidthRatio = 0.12
                
            case .iPadPortrait:
                titleFontSize = 12
                subtitleFontSize = 22
                buttonSpacing = 4
                rowSpacing = 8
                keyboardPadding = 5
                keyHeight = 80
                sideColumnWidth = 80
                candidateViewHeight = 100
                functionKeyWidthRatio = 0.2
                
            case .iPadLandscape:
                titleFontSize = 14
                subtitleFontSize = 24
                buttonSpacing = 6
                rowSpacing = 10
                keyboardPadding = 8
                keyHeight = 60
                sideColumnWidth = 80
                candidateViewHeight = 60
                functionKeyWidthRatio = 0.25
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
        ["🌐", "符", "  space  ", "中", "⏎"]
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
        ["🌐", "符", "   空白鍵   ", "英", "⏎"]
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
        ["🌐", " ", "  space  ", "中", "⏎"]
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
    var inMemoryBoshiamyDict: [String: [String]] = [:]
    
    // 約束參考
    var candidateViewHeightConstraint: NSLayoutConstraint!
    
    var isBoshiamyMode = true  // true 為嘸蝦米模式，false 為英文模式
    // 添加一個狀態變量來追踪是否在"小字模式"
    var isSecondaryLabelMode = false
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
        
        print("螢幕大小: \(screenSize), 判斷為\(isLandscape ? "橫向" : "直向")")
        
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
        
        // 更新尺寸參數
        keyboardMetrics = KeyboardMetrics(deviceState: currentState)
        
        // 應用新的尺寸參數
        applyKeyboardMetrics()
    }

    // 應用尺寸參數到視圖
    func applyKeyboardMetrics() {
        // 更新候選區高度約束
        candidateViewHeightConstraint.constant = keyboardMetrics.candidateViewHeight
        
        // 更新字體大小
        // 更新輸入代碼顯示區域的字體
        inputCodeLabel.font = UIFont.systemFont(ofSize: keyboardMetrics.subtitleFontSize)
        
        // 更新候選區按鈕的字體大小
        for button in candidateButtons {
            button.titleLabel?.font = UIFont.systemFont(ofSize: keyboardMetrics.subtitleFontSize)
        }
        
        // 更新鍵盤視圖的間距和邊距
        // 查找並更新鍵盤堆疊視圖的間距
        keyboardView.subviews.forEach { subview in
            if let stackView = subview as? UIStackView {
                // 假設這是主堆疊視圖
                for arrangedSubview in stackView.arrangedSubviews {
                    if let rowStackView = arrangedSubview as? UIStackView {
                        // 水平間距 (按鈕間間距)
                        rowStackView.spacing = keyboardMetrics.buttonSpacing
                    }
                }
                // 垂直間距 (行間間距)
                stackView.spacing = keyboardMetrics.rowSpacing
            }
        }
        
        // 更新鍵盤邊距約束
        for constraint in keyboardView.constraints {
            if let firstItem = constraint.firstItem as? NSObject,
               firstItem == keyboardView {
                // 尋找邊距約束
                if constraint.firstAttribute == .top || constraint.firstAttribute == .bottom ||
                   constraint.firstAttribute == .leading || constraint.firstAttribute == .trailing {
                    constraint.constant = keyboardMetrics.keyboardPadding
                }
            }
        }
        
        // 更新按鈕高度約束
        updateButtonHeights()
        
        // 根據設備狀態重新計算鍵盤視圖高度
        updateKeyboardViewHeight()
        
        // 強制立即更新佈局
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // 打印日誌以確認應用了正確的尺寸
        print("應用鍵盤尺寸參數 - 設備狀態: \(keyboardMetrics.deviceState), 按鍵高度: \(keyboardMetrics.keyHeight), 候選區高度: \(keyboardMetrics.candidateViewHeight)")
    }

    // 輔助方法：更新所有按鈕的高度
    private func updateButtonHeights() {
        for rowButtons in keyButtons {
            for button in rowButtons {
                // 移除現有高度約束
                for constraint in button.constraints {
                    if constraint.firstAttribute == .height {
                        button.removeConstraint(constraint)
                    }
                }
                
                // 添加新的高度約束
                let heightConstraint = button.heightAnchor.constraint(equalToConstant: keyboardMetrics.keyHeight)
                heightConstraint.isActive = true
            }
        }
    }

    // 輔助方法：根據設備狀態更新鍵盤視圖高度
    private func updateKeyboardViewHeight() {
        // 移除現有的鍵盤視圖高度約束
        for constraint in view.constraints {
            if let firstItem = constraint.firstItem as? NSObject,
               firstItem == keyboardView && constraint.firstAttribute == .height {
                view.removeConstraint(constraint)
            }
        }
        
        // 根據設備狀態添加適當的高度約束
        if keyboardMetrics.deviceState == .iPhoneLandscape {
            // iPhone 橫屏模式 - 使用螢幕高度的固定比例
            let screenHeight = UIScreen.main.bounds.height
            let keyboardHeight = screenHeight * 0.45 - keyboardMetrics.candidateViewHeight
            keyboardView.heightAnchor.constraint(equalToConstant: keyboardHeight).isActive = true
        } else {
            // 其他模式處理...
            // 如果需要特定高度約束，可以在這裡添加
        }
    }
    
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
    
    
    
    
    // 生命週期方法
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 初始化鍵盤尺寸參數
        keyboardMetrics = KeyboardMetrics(deviceState: getCurrentDeviceState())
        
        // 設置基本視圖框架
        setupViews()
        
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
                        print("為按鍵 \(keyTitle) 添加長按手勢，次要標籤: \(secondaryText)")
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
        // 創建頂部視圖容器 - 這將包含候選字視圖和側按鈕
        let topContainer = UIView()
        topContainer.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topContainer)
        
        // 創建左側 Enter 按鈕 - 直接添加到頂部容器
        let enterButton = UIButton(type: .system)
        enterButton.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        enterButton.setTitle("⏎", for: .normal)
        enterButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        enterButton.layer.cornerRadius = 4
        enterButton.layer.borderWidth = 0.5
        enterButton.layer.borderColor = UIColor.darkGray.cgColor
        enterButton.tag = 3001
        enterButton.addTarget(self, action: #selector(candidateAreaButtonPressed(_:)), for: .touchUpInside)
        enterButton.translatesAutoresizingMaskIntoConstraints = false
        topContainer.addSubview(enterButton)
        
        // 創建右側 Backspace 按鈕 - 直接添加到頂部容器
        let backspaceButton = UIButton(type: .system)
        backspaceButton.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        backspaceButton.setTitle("⌫", for: .normal)
        backspaceButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
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
        
        topContainer.addSubview(backspaceButton)
        
        // 創建候選字滾動視圖 - 在Enter和Backspace按鈕之間
        candidateView = UIScrollView()
        candidateView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        candidateView.translatesAutoresizingMaskIntoConstraints = false
        candidateView.isScrollEnabled = true
        candidateView.showsHorizontalScrollIndicator = false
        candidateView.showsVerticalScrollIndicator = false
        candidateView.bounces = true
        candidateView.alwaysBounceHorizontal = true
        topContainer.addSubview(candidateView)
        
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
        
        // 計算按鈕寬度 - 根據設備調整
        let sideBtnWidth: CGFloat = isIPhone ? 80 : 100
        
        // 設置約束
        NSLayoutConstraint.activate([
            // 頂部容器約束
            topContainer.topAnchor.constraint(equalTo: view.topAnchor),
            topContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topContainer.heightAnchor.constraint(equalToConstant: keyboardMetrics.candidateViewHeight), // 固定高度
            
            // 左側 Enter 按鈕約束 - 固定在頂部容器左側
            enterButton.leadingAnchor.constraint(equalTo: topContainer.leadingAnchor),
            enterButton.centerYAnchor.constraint(equalTo: topContainer.centerYAnchor),
            enterButton.widthAnchor.constraint(equalToConstant: sideBtnWidth),
            enterButton.heightAnchor.constraint(equalToConstant: keyboardMetrics.candidateViewHeight),
            
            // 右側 Backspace 按鈕約束 - 固定在頂部容器右側
            backspaceButton.trailingAnchor.constraint(equalTo: topContainer.trailingAnchor),
            backspaceButton.centerYAnchor.constraint(equalTo: topContainer.centerYAnchor),
            backspaceButton.widthAnchor.constraint(equalToConstant: sideBtnWidth),
            backspaceButton.heightAnchor.constraint(equalToConstant: keyboardMetrics.candidateViewHeight),
            
            // 候選字滾動視圖約束 - 在左右按鈕之間
            candidateView.leadingAnchor.constraint(equalTo: enterButton.trailingAnchor, constant: 5),
            candidateView.trailingAnchor.constraint(equalTo: backspaceButton.leadingAnchor, constant: -5),
            candidateView.topAnchor.constraint(equalTo: topContainer.topAnchor),
            candidateView.bottomAnchor.constraint(equalTo: topContainer.bottomAnchor),
            
            // 輸入字碼標籤約束
            inputCodeLabel.topAnchor.constraint(equalTo: candidateView.topAnchor, constant: 5),
            inputCodeLabel.leadingAnchor.constraint(equalTo: candidateView.leadingAnchor, constant: 10),
            inputCodeLabel.heightAnchor.constraint(equalToConstant: 40),
            
            // 鍵盤視圖約束
            keyboardView.topAnchor.constraint(equalTo: topContainer.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 保存頂部容器高度約束以便後續更改
        candidateViewHeightConstraint =  topContainer.heightAnchor.constraint(equalToConstant: keyboardMetrics.candidateViewHeight)
        candidateViewHeightConstraint.isActive = true
        
        // 初始化空的候選字視圖和清空輸入字碼
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

    // 獲取按鈕索引
    private func getButtonIndices(_ button: UIButton) -> (Int, Int) {
        let row = button.tag / 100
        let col = button.tag % 100
        return (row, col)
    }

    // 獲取按鍵標題
    private func getKeyTitle(_ row: Int, _ col: Int) -> String? {
        let currentLayout: [[String]]
        if isSymbolMode {
            currentLayout = symbolRows
        } else {
            currentLayout = isBoshiamyMode ? boshiamySymbols : keyboardRows
        }
        
        guard row < currentLayout.count && col < currentLayout[row].count else {
            print("無效的按鍵索引: row \(row), col \(col)")
            return nil
        }
        
        return currentLayout[row][col]
    }

    // 處理特殊情況
    private func handleSpecialCase(_ key: String) -> Bool {
        // 處理同音字反查
        if key == "、" && isBoshiamyMode {
            startHomophoneLookup()
            return true
        }
        
        // 處理同音字反查模式下的按鍵
        if isHomophoneLookupMode {
            handleHomophoneLookupKeyPress(key)
            return true
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
        if isBoshiamyMode && !collectedRoots.isEmpty {
            collectedRoots = String(collectedRoots.dropLast())
            updateInputCodeDisplay(collectedRoots)
            
            if collectedRoots.isEmpty {
                displayCandidates([])
            } else {
                let candidates = lookupBoshiamyDictionary(collectedRoots)
                displayCandidates(candidates)
            }
        } else {
            textDocumentProxy.deleteBackward()
        }
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
        print("重新創建鍵盤 - 當前設備狀態: \(keyboardMetrics.deviceState), 按鍵高度: \(keyboardMetrics.keyHeight), 候選區高度: \(keyboardMetrics.candidateViewHeight)")
        
        // 清除現有按鍵
        keyboardView.subviews.forEach { $0.removeFromSuperview() }
        keyButtons.removeAll()
        
        // 先移除所有與 keyboardView 相關的高度約束
        for constraint in view.constraints {
            if let firstItem = constraint.firstItem as? NSObject,
               firstItem == keyboardView && constraint.firstAttribute == .height {
                view.removeConstraint(constraint)
            }
        }
        
        // 根據設備狀態設定適當的高度約束
        if keyboardMetrics.deviceState == .iPhoneLandscape {
            // iPhone 橫屏模式 - 使用螢幕高度的固定比例
            let screenHeight = UIScreen.main.bounds.height
            let keyboardHeight = screenHeight * 0.45 // 調整為所需比例
            let heightConstraint = keyboardView.heightAnchor.constraint(equalToConstant: keyboardHeight)
            heightConstraint.isActive = true
        } else {
            // 其他模式 - 如果需要特定高度約束，可以在這裡添加
        }
        
        // 更新佈局
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // 重新創建按鍵
        DispatchQueue.main.async {
            self.setupKeyboardLayout()
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
    // 5. 修改 setupKeyboardLayout 方法，根據設備類型調整鍵盤佈局
    private func setupKeyboardLayout() {
        print("創建按鍵 - \(isSymbolMode ? "符號模式" : (isBoshiamyMode ? "嘸蝦米模式" : "英文模式"))")
        print("當前設備狀態: \(keyboardMetrics.deviceState), 按鍵高度: \(keyboardMetrics.keyHeight)")
        
        // 確保已經清除現有按鍵
        keyboardView.subviews.forEach { $0.removeFromSuperview() }
        keyButtons.removeAll()
        
        // 選擇當前佈局和次要標籤
        let currentLayout: [[String]]
        let currentSecondaryLabels: [[String]]
        
        if isSymbolMode {
            currentLayout = symbolRows
            currentSecondaryLabels = symbolSecondaryLabels
        } else {
            currentLayout = isBoshiamyMode ? boshiamySymbols : keyboardRows
            currentSecondaryLabels = isBoshiamyMode ? boshiamySecondaryLabels : secondaryLabels
        }
        
        // 使用尺寸參數
        let buttonSpacing = keyboardMetrics.buttonSpacing
        let rowSpacing = keyboardMetrics.rowSpacing
        let keyboardPadding = keyboardMetrics.keyboardPadding
        
        // 在 iPhone 橫屏模式或直式模式下，跳過數字鍵行
        let skipNumberRow = (keyboardMetrics.deviceState == .iPhonePortrait || keyboardMetrics.deviceState == .iPhoneLandscape) && !isSymbolMode
        
        // 關鍵修改：在 iPhone 橫屏模式下，調整鍵盤視圖的高度
        if keyboardMetrics.deviceState == .iPhoneLandscape {
            // 調整 keyboardView 的高度約束
            for constraint in view.constraints {
                if let firstItem = constraint.firstItem as? UIView,
                   firstItem == keyboardView,
                   constraint.firstAttribute == .height {
                    // 移除現有的高度約束
                    view.removeConstraint(constraint)
                    break
                }
            }
            
            // 添加新的高度約束，使鍵盤高度為螢幕高度的 50%
            let screenHeight = UIScreen.main.bounds.height
            let desiredKeyboardHeight = screenHeight * 0.5 - keyboardMetrics.candidateViewHeight
            keyboardView.heightAnchor.constraint(equalToConstant: desiredKeyboardHeight).isActive = true
        }
        
        // 創建主容器
        let mainHorizontalStackView = UIStackView()
        mainHorizontalStackView.axis = .horizontal
        mainHorizontalStackView.distribution = .fill
        mainHorizontalStackView.spacing = buttonSpacing
        mainHorizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.addSubview(mainHorizontalStackView)
        
        // 設置主容器約束
        NSLayoutConstraint.activate([
            mainHorizontalStackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: keyboardPadding),
            mainHorizontalStackView.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: keyboardPadding),
            mainHorizontalStackView.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -keyboardPadding),
            mainHorizontalStackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -keyboardPadding)
        ])
        
        // 創建主鍵盤容器
        let mainKeyboardStackView = UIStackView()
        mainKeyboardStackView.axis = .vertical
        mainKeyboardStackView.distribution = .fillEqually // 改回 fillEqually 使所有行高度相等
        mainKeyboardStackView.spacing = rowSpacing
        mainKeyboardStackView.translatesAutoresizingMaskIntoConstraints = false
        mainHorizontalStackView.addArrangedSubview(mainKeyboardStackView)
        
        
        
        for (rowIndex, row) in currentLayout.enumerated() {
            // 跳過不需要的行
            if skipNumberRow && rowIndex == 0 {
                continue
            }
            
            // 檢查是否為最後一行（特殊處理）
            let isLastRow = rowIndex == currentLayout.count - 1
            
            // 創建行堆疊視圖
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            // 如果是最後一行，使用不同的分配方式
            if isLastRow {
                rowStackView.distribution = .fill  // 填充模式，允許不同寬度
            } else {
                rowStackView.distribution = .fillEqually  // 其他行平均分配
            }
            rowStackView.spacing = buttonSpacing
            rowStackView.translatesAutoresizingMaskIntoConstraints = false
            
            // 明確設置行高度，使用 keyboardMetrics.keyHeight
            rowStackView.heightAnchor.constraint(equalToConstant: keyboardMetrics.keyHeight).isActive = true
            
            var rowButtons = [UIButton]()
            
            // 如果是普通行，先計算按鈕的標準寬度
            var standardWidth: CGFloat = 0
            if !isLastRow {
                standardWidth = (keyboardView.bounds.width - (2 * keyboardPadding) - ((CGFloat(row.count) - 1) * buttonSpacing)) / CGFloat(row.count)
            }
            
            for (keyIndex, keyTitle) in row.enumerated() {
                // 創建按鈕
                let button = configureKeyButton(keyTitle: keyTitle, rowIndex: rowIndex, keyIndex: keyIndex, currentSecondaryLabels: currentSecondaryLabels)
                button.translatesAutoresizingMaskIntoConstraints = false
                rowStackView.addArrangedSubview(button)
                rowButtons.append(button)
                
                // 為普通行的按鈕設置相同寬度
                if !isLastRow {
                    button.widthAnchor.constraint(equalToConstant: standardWidth).isActive = true
                }
            }
            
            // 添加這一行到主鍵盤堆疊視圖
            mainKeyboardStackView.addArrangedSubview(rowStackView)
            keyButtons.append(rowButtons)
            
            // 只在最後添加最後一行的按鍵後設置其特殊寬度
            if isLastRow {
                // 延遲處理，確保視圖已經加載
                DispatchQueue.main.async {
                    self.configureLastRowWidths(buttons: rowButtons)
                }
            }
        }
        
        // 在鍵盤創建完成後設置長按手勢
        DispatchQueue.main.async {
            self.setupLongPressGestures()
        }
    }
    
    // 專門用於配置最後一行按鈕寬度的方法
    private func configureLastRowWidths(buttons: [UIButton]) {
        // 確保該方法在主隊列執行
        DispatchQueue.main.async {
            // 獲取父視圖
            let parentView = buttons.first?.superview
            
            // 首先強制更新布局
            parentView?.setNeedsLayout()
            parentView?.layoutIfNeeded()
            
            // 然後再獲取父視圖寬度
            guard let parentWidth = parentView?.bounds.width else {
                print("無法獲取父視圖寬度")
                return
            }
            
            // 後續代碼保持不變
            let buttonSpacing = self.keyboardMetrics.buttonSpacing
            let totalSpacing = buttonSpacing * CGFloat(buttons.count - 1)
            let availableWidth = parentWidth
            
            // 找出空白鍵的索引
            var spaceKeyIndex = -1
            for (index, button) in buttons.enumerated() {
                let buttonTitle = button.title(for: .normal) ?? ""
                if buttonTitle.contains("space") || buttonTitle.contains("空白鍵") || buttonTitle.contains("  ") {
                    spaceKeyIndex = index
                    break
                }
            }
            
            // 如果找不到空白鍵，使用默認值
            if spaceKeyIndex == -1 {
                spaceKeyIndex = 2
                print("無法找到空白鍵，默認使用索引1")
            }
            
            // 移除所有現有寬度約束
            for button in buttons {
                button.constraints.forEach { constraint in
                    if constraint.firstAttribute == .width {
                        button.removeConstraint(constraint)
                    }
                }
                
                parentView?.constraints.forEach { constraint in
                    if constraint.firstItem === button && constraint.firstAttribute == .width {
                        parentView?.removeConstraint(constraint)
                    }
                }
            }
            
            // 計算各按鈕寬度
            let spaceKeyWidthRatio: CGFloat = 0.6
            let spaceKeyWidth = (availableWidth - totalSpacing) * spaceKeyWidthRatio
            let functionKeyWidth = ((availableWidth - totalSpacing) * (1 - spaceKeyWidthRatio)) / CGFloat(buttons.count - 1)
            
            // 重新設置所有按鈕寬度
            for (index, button) in buttons.enumerated() {
                let widthConstraint: NSLayoutConstraint
                if index == spaceKeyIndex {
                    widthConstraint = button.widthAnchor.constraint(equalToConstant: spaceKeyWidth)
                    widthConstraint.priority = .defaultHigh + 1
                } else {
                    widthConstraint = button.widthAnchor.constraint(equalToConstant: functionKeyWidth)
                    widthConstraint.priority = .defaultHigh
                }
                widthConstraint.isActive = true
                
                print("按鈕 \(index) 寬度設置為: \(index == spaceKeyIndex ? spaceKeyWidth : functionKeyWidth)")
            }
            
            // 最後再次強制更新布局，確保新的約束應用生效
            parentView?.setNeedsLayout()
            parentView?.layoutIfNeeded()
        }
    }
    
    private func configureKeyButton(keyTitle: String, rowIndex: Int, keyIndex: Int, currentSecondaryLabels: [[String]]) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 4
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.darkGray.cgColor
        button.tag = rowIndex * 100 + keyIndex
        button.addTarget(self, action: #selector(keyPressed(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // 使用 UIButtonConfiguration 設置按鈕樣式
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = UIColor.black
        config.background.backgroundColor = UIColor.white
        
        // 特殊按鍵使用不同背景色
        if (keyTitle == "符" || keyTitle == "ABC" ||
            keyTitle.contains("中") || keyTitle.contains("英") ||
            keyTitle.contains("🌐")) {
            config.background.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        }
        
        // 添加次要標籤（移除了iPhone設備的限制）
        if rowIndex < currentSecondaryLabels.count && keyIndex < currentSecondaryLabels[rowIndex].count {
            let secondaryText = currentSecondaryLabels[rowIndex][keyIndex]
            if !secondaryText.isEmpty {
                // 修改：移除了設備類型的檢查，允許所有設備顯示次要標籤
                
                // 根據設備調整字體大小
                let titleFontSize = keyboardMetrics.deviceState == .iPhonePortrait ||
                                   keyboardMetrics.deviceState == .iPhoneLandscape ?
                                   keyboardMetrics.titleFontSize * 0.8 : keyboardMetrics.titleFontSize
                
                let subtitleFontSize = keyboardMetrics.deviceState == .iPhonePortrait ||
                                      keyboardMetrics.deviceState == .iPhoneLandscape ?
                                      keyboardMetrics.subtitleFontSize * 0.9 : keyboardMetrics.subtitleFontSize
                
                config.titleAlignment = .center
                config.title = secondaryText
                config.subtitle = keyTitle
                config.titlePadding = 2
                
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = UIFont.systemFont(ofSize: titleFontSize)
                    outgoing.foregroundColor = UIColor.darkGray
                    return outgoing
                }
                
                config.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var outgoing = incoming
                    outgoing.font = UIFont.systemFont(ofSize: subtitleFontSize)
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
        } else {
            config.title = keyTitle
            
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: self.keyboardMetrics.subtitleFontSize)
                return outgoing
            }
        }
        
        button.configuration = config
        // 添加這段代碼：明確設置按鈕高度
        button.heightAnchor.constraint(equalToConstant: keyboardMetrics.keyHeight).isActive = true
            
        return button
    }

    // 輔助方法：判斷是否為特殊按鍵
    private func isSpecialKey(_ keyTitle: String) -> Bool {
        return keyTitle == "符" || keyTitle == "ABC" ||
               keyTitle.contains("中") || keyTitle.contains("英") ||
               keyTitle.contains("🌐")
    }

    // 輔助方法：獲取次要標籤文字
    private func getSecondaryText(_ rowIndex: Int, _ keyIndex: Int, _ labels: [[String]]) -> String? {
        guard rowIndex < labels.count && keyIndex < labels[rowIndex].count else { return nil }
        return labels[rowIndex][keyIndex]
    }

    // 輔助方法：設置雙標籤按鈕
    private func setupDualLabelButton(_ config: inout UIButton.Configuration, title: String, subtitle: String) {
        config.titleAlignment = .center
        config.title = title
        config.subtitle = subtitle
        config.titlePadding = 2
        
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
    }

    // 輔助方法：設置單標籤按鈕
    private func setupSingleLabelButton(_ config: inout UIButton.Configuration, title: String) {
        config.title = title
        
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: self.keyboardMetrics.subtitleFontSize)
            return outgoing
        }
    }
    
    
    
    // 6. 為iPhone直式模式創建簡化的右側欄
    private func createSimpleSideColumn(isLandscape: Bool, width: CGFloat) -> UIStackView {
        // 創建垂直堆疊視圖作為側欄容器
        let columnStackView = UIStackView()
        columnStackView.axis = .vertical
        columnStackView.distribution = .fillEqually
        columnStackView.spacing = 12
        columnStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 固定側欄寬度
        columnStackView.widthAnchor.constraint(equalToConstant: width).isActive = true
        
        // 創建刪除按鈕
        let deleteButton = UIButton(type: .system)
        deleteButton.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        deleteButton.setTitle("⌫", for: .normal)
        deleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        deleteButton.layer.cornerRadius = 4
        deleteButton.layer.borderWidth = 0.5
        deleteButton.layer.borderColor = UIColor.darkGray.cgColor
        deleteButton.tag = 2000  // 使用與正常側欄相同的標籤
        deleteButton.addTarget(self, action: #selector(sideButtonPressed(_:)), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加長按手勢
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressDelete(_:)))
        longPress.minimumPressDuration = 0.5
        deleteButton.addGestureRecognizer(longPress)
        
        // 創建換行按鈕
        let returnButton = UIButton(type: .system)
        returnButton.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
        returnButton.setTitle("⏎", for: .normal)
        returnButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        returnButton.layer.cornerRadius = 4
        returnButton.layer.borderWidth = 0.5
        returnButton.layer.borderColor = UIColor.darkGray.cgColor
        returnButton.tag = 2001  // 使用與正常側欄相同的標籤
        returnButton.addTarget(self, action: #selector(sideButtonPressed(_:)), for: .touchUpInside)
        returnButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加按鈕到堆疊視圖
        columnStackView.addArrangedSubview(deleteButton)
        columnStackView.addArrangedSubview(returnButton)
        
        return columnStackView
    }

    // 幫助函數：添加寬度約束
    private func addWidthConstraint(to button: UIButton, width: CGFloat) {
        let constraint = button.widthAnchor.constraint(equalToConstant: width)
        constraint.priority = .defaultHigh
        constraint.isActive = true
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
        isLongPressDeleteActive = (gesture.state == .began)
        
        if isLongPressDeleteActive {
            startDeleteTimer()
        } else {
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
        // 移除通知觀察者
        NotificationCenter.default.removeObserver(self)
        
        database?.close()
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
