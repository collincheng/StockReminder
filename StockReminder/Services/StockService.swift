//
//  StockService.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import Foundation

// MARK: - 股票数据模型

/// 股票实时数据
struct StockData: Identifiable, Codable {
    var id: String { code }
    
    let code: String           // 股票代码，如 sh600036, usr_aapl
    let name: String           // 股票名称
    let price: Double          // 当前价格
    let yestclose: Double      // 昨收价
    let open: Double           // 开盘价
    let high: Double           // 最高价
    let low: Double            // 最低价
    let volume: Double         // 成交量（累计）
    let buy1Price: Double      // 买一价
    let sell1Price: Double     // 卖一价
    var volumeDelta: Double = 0  // 每次刷新间的成交增量
    var volumeIsUp: Bool = true  // 主动买入(红)/主动卖出(绿)
    let amount: Double         // 成交额
    let time: String           // 更新时间
    
    /// 涨跌额
    var updown: Double {
        price - yestclose
    }
    
    /// 涨跌幅 (百分比)
    var percent: Double {
        guard yestclose > 0 else { return 0 }
        return (updown / yestclose) * 100
    }
    
    /// 格式化的涨跌幅字符串
    var percentText: String {
        let sign = percent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, percent)
    }
    
    /// 格式化的实时成交量字符串（每次刷新间的增量，以手为单位）
    var volumeText: String {
        // A股: API 返回股数，1手=100股；期货/港股/美股: 直接用
        let lots: Double
        switch marketType {
        case .aStock:
            lots = volumeDelta / 100
        default:
            lots = volumeDelta
        }

        if lots >= 1_0000_0000 {
            return String(format: "%.2f亿手", lots / 1_0000_0000)
        } else if lots >= 10000 {
            return String(format: "%.0f万手", lots / 10000)
        } else {
            return String(format: "%.0f手", lots)
        }
    }

    /// 是否上涨
    var isUp: Bool {
        updown >= 0
    }

    /// 是否是指数（指数没有逐笔成交，不显示成交量）
    var isIndex: Bool {
        code.hasPrefix("sh000") || code.hasPrefix("sz399") || code.hasPrefix("bj899")
    }
    
    /// 股票市场类型
    var marketType: MarketType {
        if code.hasPrefix("sh") || code.hasPrefix("sz") || code.hasPrefix("bj") {
            return .aStock
        } else if code.hasPrefix("hk") {
            return .hkStock
        } else if code.hasPrefix("usr_") || code.hasPrefix("gb_") {
            return .usStock
        } else if code.hasPrefix("nf_") {
            return .cnFuture
        } else if code.hasPrefix("hf_") {
            return .overseaFuture
        }
        return .unknown
    }
}

/// 股票市场类型
enum MarketType: String {
    case aStock = "A股"
    case hkStock = "港股"
    case usStock = "美股"
    case cnFuture = "国内期货"
    case overseaFuture = "海外期货"
    case unknown = "未知"
}

/// 分时数据（每分钟一个点）
struct MinuteData: Identifiable {
    var id: String { time }
    let time: String       // 时间，如 "09:30"
    let price: Double      // 当前价
    let volume: Double     // 该分钟成交量
    let avgPrice: Double   // 均价
}

/// 股票搜索结果
struct StockSearchResult: Identifiable {
    var id: String { code }
    
    let code: String           // 完整代码，如 sh600036
    let name: String           // 股票名称
    let market: String         // 市场，如 sh, sz, hk, us
    let abbreviation: String   // 拼音缩写
}

// MARK: - 股票服务

/// 股票数据服务
class StockService {
    static let shared = StockService()
    
    private init() {}
    
    // MARK: - API URLs
    
    /// 新浪股票数据接口
    private let sinaStockURL = "https://hq.sinajs.cn/list="
    
    /// 腾讯港股数据接口
    private let tencentStockURL = "https://qt.gtimg.cn/q="
    
    /// 腾讯股票搜索接口
    private let searchURL = "https://proxy.finance.qq.com/ifzqgtimg/appstock/smartbox/search/get"
    
    /// 新浪期货搜索接口
    private let futureSearchURL = "http://suggest3.sinajs.cn/suggest/type=85,86,88&key="
    
    // MARK: - 搜索股票
    
    /// 搜索股票
    /// - Parameter keyword: 关键词（股票代码或名称）
    /// - Returns: 搜索结果列表
    func searchStock(keyword: String) async throws -> [StockSearchResult] {
        guard !keyword.isEmpty else { return [] }
        
        // 检查是否是期货搜索（大写字母开头或包含期货前缀）
        let firstChar = keyword.first ?? Character(" ")
        let isFuture = firstChar.isUppercase || 
                       keyword.hasPrefix("nf_") || 
                       keyword.hasPrefix("hf_") ||
                       keyword.hasPrefix("fx_")
        
        if isFuture {
            return try await searchFutures(keyword: keyword)
        } else {
            return try await searchStocks(keyword: keyword)
        }
    }
    
    /// 搜索股票（腾讯接口）
    private func searchStocks(keyword: String) async throws -> [StockSearchResult] {
        var components = URLComponents(string: searchURL)!
        components.queryItems = [URLQueryItem(name: "q", value: keyword)]
        
        guard let url = components.url else {
            throw StockError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let stockArray = dataDict["stock"] as? [[String]] else {
            return []
        }
        
        return stockArray.compactMap { item -> StockSearchResult? in
            guard item.count >= 4 else { return nil }
            let market = item[0].lowercased()
            let code = item[1].lowercased()
            let name = item[2]
            let abbreviation = item[3]
            
            // 构建完整代码
            var fullCode = "\(market)\(code)"
            if market == "us" {
                // 美股代码处理，处理包含点号的情况如 BRK.B
                let codeParts = code.components(separatedBy: ".")
                if codeParts.count > 1 {
                    // 最后一部分是市场标识，去掉
                    let usCode = codeParts.dropLast().joined(separator: ".")
                    fullCode = "usr_\(usCode)"
                } else {
                    fullCode = "usr_\(code)"
                }
            }
            
            return StockSearchResult(
                code: fullCode,
                name: name,
                market: market,
                abbreviation: abbreviation
            )
        }
    }
    
    /// 搜索期货（新浪接口）
    private func searchFutures(keyword: String) async throws -> [StockSearchResult] {
        let urlString = futureSearchURL + keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        
        guard let url = URL(string: urlString) else {
            throw StockError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // 新浪接口返回 GBK 编码
        guard let responseString = decodeGBK(data: data) ?? String(data: data, encoding: .utf8) else {
            return []
        }
        
        // 解析格式: var suggestdata="期货代码,市场类型,代码,代码,名称,?,?,交易所;"
        // 提取引号中的内容
        guard let startIndex = responseString.firstIndex(of: "\""),
              let endIndex = responseString.lastIndex(of: "\""),
              startIndex < endIndex else {
            return []
        }
        
        let content = String(responseString[responseString.index(after: startIndex)..<endIndex])
        guard !content.isEmpty else { return [] }
        
        let items = content.components(separatedBy: ";")
        
        return items.compactMap { item -> StockSearchResult? in
            let parts = item.components(separatedBy: ",")
            guard parts.count >= 5 else { return nil }
            
            let marketType = parts[1]  // 85=国内期货, 86=海外期货, 88=股指期货
            var code = parts[3].uppercased()
            let name = parts[4]
            
            // 根据市场类型添加前缀
            var market = "nf"
            if marketType == "85" || marketType == "88" {
                code = "nf_\(code)"
                market = "nf"
            } else if marketType == "86" {
                code = "hf_\(code)"
                market = "hf"
            }
            
            let exchange = parts.count > 7 ? parts[7].replacingOccurrences(of: "\"", with: "") : ""
            
            return StockSearchResult(
                code: code,
                name: name,
                market: market,
                abbreviation: exchange
            )
        }
    }
    
    // MARK: - 获取股票数据
    
    /// 获取股票实时数据
    /// - Parameter codes: 股票代码列表，如 ["sh600036", "usr_aapl"]
    /// - Returns: 股票数据列表
    func getStockData(codes: [String]) async throws -> [StockData] {
        guard !codes.isEmpty else { return [] }
        
        // 分离港股和其他股票
        var otherCodesTemp: [String] = []
        var hkCodesTemp: [String] = []
        
        for code in codes {
            if code.hasPrefix("hk") {
                hkCodesTemp.append(code)
            } else {
                otherCodesTemp.append(code)
            }
        }
        
        // 创建不可变副本以安全地在并发代码中使用
        let otherCodes = otherCodesTemp
        let hkCodes = hkCodesTemp
        
        // 并发请求
        async let otherStocks = getStockDataFromSina(codes: otherCodes)
        async let hkStocks = getHKStockData(codes: hkCodes)
        
        let results = try await [otherStocks, hkStocks]
        return results.flatMap { $0 }
    }
    
    /// 从新浪获取股票数据（A股、美股、期货）
    private func getStockDataFromSina(codes: [String]) async throws -> [StockData] {
        guard !codes.isEmpty else { return [] }
        
        let codesStr = codes.joined(separator: ",")
        guard let url = URL(string: sinaStockURL + codesStr) else {
            throw StockError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("http://finance.sina.com.cn/", forHTTPHeaderField: "Referer")
        request.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // 新浪返回 GBK 编码，需要转换
        guard let responseString = String(data: data, encoding: .utf8) ??
                                   decodeGBK(data: data) else {
            throw StockError.decodingError
        }
        
        return parseSinaResponse(responseString, codes: codes)
    }
    
    /// 解析新浪接口返回的数据
    private func parseSinaResponse(_ response: String, codes: [String]) -> [StockData] {
        var stocks: [StockData] = []
        
        let lines = response.components(separatedBy: ";\n")
        
        for line in lines {
            guard line.contains("=\"") else { continue }
            
            let parts = line.components(separatedBy: "=\"")
            guard parts.count >= 2 else { continue }
            
            // 提取股票代码
            var code = parts[0].replacingOccurrences(of: "var hq_str_", with: "")
            code = code.replacingOccurrences(of: "$", with: ".")
            
            let dataStr = parts[1].replacingOccurrences(of: "\"", with: "")
            let params = dataStr.components(separatedBy: ",")
            
            guard params.count > 1 else { continue }
            
            var stock: StockData?
            
            if code.hasPrefix("sh") || code.hasPrefix("sz") || code.hasPrefix("bj") {
                // A股
                stock = parseAStock(code: code, params: params)
            } else if code.hasPrefix("usr_") {
                // 美股
                stock = parseUSStock(code: code, params: params)
            } else if code.hasPrefix("gb_") {
                // 美股（旧格式）
                stock = parseGBStock(code: code, params: params)
            } else if code.hasPrefix("nf_") {
                // 国内期货
                stock = parseCNFuture(code: code, params: params)
            } else if code.hasPrefix("hf_") {
                // 海外期货
                stock = parseOverseaFuture(code: code, params: params)
            }
            
            if let stock = stock {
                stocks.append(stock)
            }
        }
        
        return stocks
    }
    
    /// 解析 A 股数据
    private func parseAStock(code: String, params: [String]) -> StockData? {
        guard params.count >= 32 else { return nil }
        
        let name = params[0]
        let open = Double(params[1]) ?? 0
        let yestclose = Double(params[2]) ?? 0
        var price = Double(params[3]) ?? 0
        let high = Double(params[4]) ?? 0
        let low = Double(params[5]) ?? 0
        let volume = Double(params[8]) ?? 0
        let amount = Double(params[9]) ?? 0
        let time = "\(params[30]) \(params[31])"
        
        let buy1Price = Double(params[6]) ?? 0
        let sell1Price = Double(params[7]) ?? 0

        // 如果当前价为0，使用买一价或昨收价
        if price == 0 {
            price = buy1Price != 0 ? buy1Price : yestclose
        }

        return StockData(
            code: code,
            name: name,
            price: price,
            yestclose: yestclose,
            open: open,
            high: high,
            low: low,
            volume: volume,
            buy1Price: buy1Price,
            sell1Price: sell1Price,
            amount: amount,
            time: time
        )
    }
    
    /// 解析美股数据 (usr_ 开头)
    private func parseUSStock(code: String, params: [String]) -> StockData? {
        guard params.count >= 27 else { return nil }
        
        let name = params[0]
        var price = Double(params[1]) ?? 0
        let open = Double(params[5]) ?? 0
        let high = Double(params[6]) ?? 0
        let low = Double(params[7]) ?? 0
        let volume = Double(params[10]) ?? 0
        let yestclose = Double(params[26]) ?? 0
        let time = params[3]
        
        // 盘前盘后价格处理
        let preMarketPrice = Double(params[21]) ?? 0
        if preMarketPrice > 0 && price == 0 {
            price = preMarketPrice
        }
        
        return StockData(
            code: code,
            name: name,
            price: price,
            yestclose: yestclose,
            open: open,
            high: high,
            low: low,
            volume: volume,
            buy1Price: 0,
            sell1Price: 0,
            amount: 0,
            time: time
        )
    }

    /// 解析美股数据 (gb_ 开头，旧格式)
    private func parseGBStock(code: String, params: [String]) -> StockData? {
        guard params.count >= 27 else { return nil }
        
        let name = params[0]
        let price = Double(params[1]) ?? 0
        let open = Double(params[5]) ?? 0
        let high = Double(params[6]) ?? 0
        let low = Double(params[7]) ?? 0
        let volume = Double(params[10]) ?? 0
        let yestclose = Double(params[26]) ?? 0
        
        return StockData(
            code: code,
            name: name,
            price: price,
            yestclose: yestclose,
            open: open,
            high: high,
            low: low,
            volume: volume,
            buy1Price: 0,
            sell1Price: 0,
            amount: 0,
            time: ""
        )
    }

    /// 解析国内期货数据
    private func parseCNFuture(code: String, params: [String]) -> StockData? {
        guard params.count >= 15 else { return nil }
        
        var name = params[0]
        var open = Double(params[2]) ?? 0
        var high = Double(params[3]) ?? 0
        var low = Double(params[4]) ?? 0
        var price = Double(params[8]) ?? 0
        var yestclose = Double(params[10]) ?? 0
        var volume = Double(params[14]) ?? 0
        
        // 股指期货特殊处理
        if code.contains("IF") || code.contains("IC") || code.contains("IH") || code.contains("IM") {
            if params.count >= 50 {
                name = params[49].replacingOccurrences(of: "\"", with: "")
                open = Double(params[0]) ?? 0
                high = Double(params[1]) ?? 0
                low = Double(params[2]) ?? 0
                price = Double(params[3]) ?? 0
                volume = Double(params[4]) ?? 0
                yestclose = Double(params[13]) ?? 0
            }
        }
        
        return StockData(
            code: code,
            name: name,
            price: price,
            yestclose: yestclose,
            open: open,
            high: high,
            low: low,
            volume: volume,
            buy1Price: 0,
            sell1Price: 0,
            amount: 0,
            time: ""
        )
    }

    /// 解析海外期货数据
    private func parseOverseaFuture(code: String, params: [String]) -> StockData? {
        guard params.count >= 14 else { return nil }
        
        let price = Double(params[0]) ?? 0
        let open = Double(params[8]) ?? 0
        let high = Double(params[4]) ?? 0
        let low = Double(params[5]) ?? 0
        let yestclose = Double(params[7]) ?? 0
        let time = "\(params[12]) \(params[6])"
        var name = params[13]
        name = name.replacingOccurrences(of: "\"", with: "")
        
        var volume: Double = 0
        if params.count >= 15 {
            let volumeStr = params[14].replacingOccurrences(of: "\"", with: "")
            volume = Double(volumeStr) ?? 0
        }
        
        return StockData(
            code: code,
            name: name,
            price: price,
            yestclose: yestclose,
            open: open,
            high: high,
            low: low,
            volume: volume,
            buy1Price: 0,
            sell1Price: 0,
            amount: 0,
            time: time
        )
    }

    /// 获取港股数据（从腾讯接口）
    private func getHKStockData(codes: [String]) async throws -> [StockData] {
        guard !codes.isEmpty else { return [] }
        
        // 腾讯港股接口格式：r_hk00700（小写）
        let hkCodes = codes.map { code -> String in
            // 确保格式正确：hk + 5位数字
            let cleanCode = code.lowercased().replacingOccurrences(of: "hk", with: "")
            return "r_hk\(cleanCode)"
        }.joined(separator: ",")
        
        guard let url = URL(string: "\(tencentStockURL)\(hkCodes)") else {
            throw StockError.invalidURL
        }
        
        print("港股请求URL: \(url)")
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let responseString = decodeGBK(data: data) ?? String(data: data, encoding: .utf8) else {
            throw StockError.decodingError
        }
        
        print("港股响应: \(responseString.prefix(500))")
        
        // 腾讯接口返回的是类似 JSON 的格式
        return parseHKStockResponse(responseString, codes: codes)
    }
    
    /// 解析港股数据响应
    private func parseHKStockResponse(_ response: String, codes: [String]) -> [StockData] {
        var stocks: [StockData] = []
        
        for code in codes {
            // 港股代码格式：hk00700 -> r_hk00700
            let cleanCode = code.lowercased().replacingOccurrences(of: "hk", with: "")
            let searchCode = "r_hk\(cleanCode)"
            let pattern = "\(searchCode)=\"([^\"]*)\""
            
            print("港股解析 - 搜索模式: \(pattern)")
            
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
                  let range = Range(match.range(at: 1), in: response) else {
                print("港股解析失败 - 未匹配到: \(searchCode)")
                continue
            }
            
            let dataStr = String(response[range])
            let params = dataStr.components(separatedBy: "~")
            
            print("港股解析 - 参数数量: \(params.count)")
            
            // 腾讯接口至少需要 45 个参数
            guard params.count >= 45 else {
                print("港股解析失败 - 参数不足: \(params.count)")
                continue
            }
            
            let name = params[1]
            let price = Double(params[3]) ?? 0
            let yestclose = Double(params[4]) ?? 0
            let open = Double(params[5]) ?? 0
            let high = Double(params[33]) ?? 0
            let low = Double(params[34]) ?? 0
            let volume = Double(params[36]) ?? 0
            let amount = Double(params[37]) ?? 0
            let time = params[30]
            
            let buy1Price = Double(params[9]) ?? 0
            let sell1Price = Double(params[19]) ?? 0

            let stock = StockData(
                code: code.lowercased(),
                name: name,
                price: price,
                yestclose: yestclose,
                open: open,
                high: high,
                low: low,
                volume: volume,
                buy1Price: buy1Price,
                sell1Price: sell1Price,
                amount: amount,
                time: time
            )
            stocks.append(stock)
            print("港股解析成功: \(name) - \(price)")
        }
        
        return stocks
    }
    
    // MARK: - 分时数据

    /// 获取分时数据（当天每分钟价格和成交量）
    func getMinuteData(code: String, yestclose: Double) async throws -> [MinuteData] {
        if code.hasPrefix("hk") {
            return try await getHKMinuteData(code: code, yestclose: yestclose)
        } else {
            return try await getSinaMinuteData(code: code, yestclose: yestclose)
        }
    }

    /// 新浪分时数据（A股、美股、期货）
    private func getSinaMinuteData(code: String, yestclose: Double) async throws -> [MinuteData] {
        let urlString = "https://quotes.sina.cn/cn/api/jsonp_v2.php/var%20_result=/CN_MarketDataService.getKLineData?symbol=\(code)&scale=1&ma=no&datalen=240"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("http://finance.sina.com.cn/", forHTTPHeaderField: "Referer")
        request.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let responseString = String(data: data, encoding: .utf8) else { return [] }

        // 响应格式: var _result=([{day:"2026-04-14 09:31:00",open:"35.50",high:...,low:...,close:"35.60",volume:"12345"}, ...])
        // 提取 JSON 数组部分
        guard let startIndex = responseString.firstIndex(of: "("),
              let endIndex = responseString.lastIndex(of: ")") else { return [] }

        let jsonStr = String(responseString[responseString.index(after: startIndex)..<endIndex])
        guard let jsonData = jsonStr.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: String]] else { return [] }

        var runningVolume: Double = 0
        var runningAmount: Double = 0
        return array.compactMap { item -> MinuteData? in
            guard let day = item["day"],
                  let closeStr = item["close"], let close = Double(closeStr),
                  let volStr = item["volume"], let vol = Double(volStr) else { return nil }

            // 提取时间部分 "2026-04-14 09:31:00" -> "09:31"
            let time: String
            if day.count >= 16 {
                let startIdx = day.index(day.startIndex, offsetBy: 11)
                let endIdx = day.index(day.startIndex, offsetBy: 16)
                time = String(day[startIdx..<endIdx])
            } else {
                time = day
            }

            runningVolume += vol
            let price = close
            // 用成交额/成交量近似均价，如果没有成交额就用 (open+close)/2 近似
            if let openStr = item["open"], let openPrice = Double(openStr) {
                runningAmount += (openPrice + close) / 2 * vol
            }
            let avgPrice = runningVolume > 0 ? runningAmount / runningVolume : price

            return MinuteData(time: time, price: price, volume: vol, avgPrice: avgPrice)
        }
    }

    /// 腾讯分时数据（港股）
    private func getHKMinuteData(code: String, yestclose: Double) async throws -> [MinuteData] {
        let cleanCode = code.lowercased().replacingOccurrences(of: "hk", with: "")
        let urlString = "https://ifzq.gtimg.cn/appstock/app/minute/query?_var=min_data&code=hk\(cleanCode)"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let responseString = String(data: data, encoding: .utf8) else { return [] }

        // 提取 JSON 部分
        guard let eqIndex = responseString.firstIndex(of: "=") else { return [] }
        let jsonStr = String(responseString[responseString.index(after: eqIndex)...])
        guard let jsonData = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let codeDict = dataDict["hk\(cleanCode)"] as? [String: Any],
              let dataInfo = codeDict["data"] as? [String: Any],
              let minuteArr = dataInfo["minute"] as? [[String: Any]] else { return [] }

        var runningVolume: Double = 0
        var runningAmount: Double = 0
        return minuteArr.compactMap { item -> MinuteData? in
            guard let time = item["time"] as? String,
                  let priceStr = item["price"] as? String, let price = Double(priceStr),
                  let volStr = item["volume"] as? String, let vol = Double(volStr) else { return nil }

            // 格式化时间 "0930" -> "09:30"
            let formattedTime: String
            if time.count == 4 {
                let idx = time.index(time.startIndex, offsetBy: 2)
                formattedTime = "\(time[..<idx]):\(time[idx...])"
            } else {
                formattedTime = time
            }

            runningVolume += vol
            runningAmount += price * vol
            let avgPrice = runningVolume > 0 ? runningAmount / runningVolume : price

            return MinuteData(time: formattedTime, price: price, volume: vol, avgPrice: avgPrice)
        }
    }

    // MARK: - 辅助方法

    /// GBK 解码
    private func decodeGBK(data: Data) -> String? {
        let cfEncoding = CFStringEncodings.GB_18030_2000
        let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEncoding.rawValue))
        return String(data: data, encoding: String.Encoding(rawValue: encoding))
    }
    
    /// 生成随机 User-Agent
    private func randomUserAgent() -> String {
        let agents = [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ]
        return agents.randomElement() ?? agents[0]
    }
}

// MARK: - 错误类型

enum StockError: LocalizedError {
    case invalidURL
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .decodingError:
            return "数据解析失败"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}

