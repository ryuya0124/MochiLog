import Foundation

struct LogParser {
    
    // 解析結果をまとめる構造体
    struct ParseResult {
        var cycleCount: Int?
        var maxCapacityPercent: Double?
        var nominalChargeCapacity: Int? // 現在のフル充電容量
        var designCapacity: Int?        // 設計容量
    }
    
    // テキスト全文を受け取り、結果を返す関数
    static func parse(text: String) -> ParseResult {
        var result = ParseResult()
        
        // 1. サイクルカウントを探す (正規表現: "last_value_CycleCount": 123)
        if let count = extractInt(from: text, key: "last_value_CycleCount") {
            result.cycleCount = count
        }
        
        // 2. 最大容量(%)を探す
        if let maxPercent = extractInt(from: text, key: "last_value_MaximumCapacityPercent") {
            result.maxCapacityPercent = Double(maxPercent)
        }
        
        // 3. 現在の実容量(mAh)を探す
        if let nominal = extractInt(from: text, key: "last_value_NominalChargeCapacity") {
            result.nominalChargeCapacity = nominal
        }
        
        // 4. 設計容量(mAh)を探す (これが取れない機種もある)
        if let design = extractInt(from: text, key: "last_value_DesignCapacity") {
            result.designCapacity = design
        } else {
            // 取れない場合は一般的な値を仮置き（後で機種判定ロジックを入れると完璧）
            result.designCapacity = result.nominalChargeCapacity // 仮
        }
        
        return result
    }
    
    // ヘルパー関数: 指定したキーの直後の数字を抜き出す
    private static func extractInt(from text: String, key: String) -> Int? {
        // パターン: "key": 数字 または "key":数字
        let pattern = "\"\(key)\"\\s*:\\s*(\\d+)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            
            if let match = results.first, let range = Range(match.range(at: 1), in: text) {
                return Int(text[range])
            }
        } catch {
            print("Regex Error: \(error)")
        }
        return nil
    }
}