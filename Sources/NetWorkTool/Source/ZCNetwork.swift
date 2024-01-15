

import UIKit
import Alamofire
import Moya
import AdSupport
import Combine

public typealias ZCCancellable = Moya.Cancellable

public class ZCNetworkTask {
    public let identifier: String
    public var wrapper: ZCCancellable
    
    init(identifier: String, wrapper: ZCCancellable) {
        self.identifier = identifier
        self.wrapper = wrapper
    }
}

private func JSONResponseDataFormatter(_ data: Data) -> String {
    do {
        let dataAsJSON = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: dataAsJSON, options: .prettyPrinted)
        return String(data: prettyData, encoding: .utf8) ?? String(data: data, encoding: .utf8) ?? ""
    } catch {
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private let plugins: [PluginType] = {
    let activityPlugin = ZCActivityPlugin()
    let netLoggerPlugin = ZCNetWorkLoggerPlugin(configuration: .init(formatter: .init(responseData: JSONResponseDataFormatter), logOptions: [.requestBody, .successResponseBody, .errorResponseBody]))
    return [netLoggerPlugin, activityPlugin]
}()

// MARK: - Headers
let endpointClosure = { (target: MultiTarget) -> Endpoint in
    
    let url = target.baseURL.appendingPathComponent(target.path).absoluteString
    
    let endpoint = Endpoint.init(url: url, sampleResponseClosure: { .networkResponse(200, target.sampleData) }, method: target.method, task: target.task, httpHeaderFields: target.headers)
    var headers = target.headers
    return endpoint.adding(newHTTPHeaderFields: headers!)
}

let stubClosure = { (target: MultiTarget) -> Moya.StubBehavior in
    if let scheme = target.baseURL.scheme, scheme == "test" {
        return Moya.StubBehavior.delayed(seconds: 3)
    }
    return Moya.StubBehavior.never
}

/// 超时时间
let requestTimeoutClosure = { (endpoint: Endpoint, done: @escaping MoyaProvider<MultiTarget>.RequestResultClosure) in
    do {
        var request = try endpoint.urlRequest()
        request.timeoutInterval = 15
        done(.success(request))
    } catch {
        return
    }
}

public let provider = MoyaProvider<MultiTarget>(endpointClosure: endpointClosure, requestClosure: requestTimeoutClosure, stubClosure: stubClosure, session: MoyaConfig.apiSession, plugins: plugins)
public let downloadProvider = MoyaProvider<MultiTarget>(plugins: plugins)
public typealias ZCNetWorkResultBlock<T> = (ZCResult<T, ZCNetworkError>) -> Void

public class ZCNetwork {
    
    
    struct Metric {
        static let deviceIdKey = "deviceIdfvKey"
    }
    public var diviceId: String = ""
    public static let shared = ZCNetwork()
    private init() {
        
    }
    
    public var showUpgradeBlock: ((_ msg: String) -> Void)?
    public var generalErrorCallBack: ((_ code: Int, _ msg: String) -> Void)?
    
    public var baseURL: URL?
    public var imageBaseUrl: String = ""

    public var session: String?
    
    var reachability = NetworkReachabilityManager()
    public var isReachableOnCellular: Bool {
        get {
            return reachability?.isReachableOnCellular ?? false
        }
    }
    public var isReachableOnEthernetOrWiFi: Bool {
        get {
            return reachability?.isReachableOnEthernetOrWiFi ?? false
        }
    }
    public var isReachable: Bool {
        get {
            return reachability?.isReachable ?? false
        }
    }
    

    @discardableResult
    public func request<T: Decodable>(api: TargetType & ZCApiProtocol, completion: ZCNetWorkResultBlock<T>? = nil) -> ZCNetworkTask? {
        if api.loginPolicy == .needLogin && self.session == nil {
            return nil
        }
        
        let wrapper = provider.request(MultiTarget(api)) { (result) in
            var hudMessage = ""
            switch result {
            case .success(let response):
                do {
                    let decoder = JSONDecoder()
                    let serverRes = try response.map(ZCResponseModel<T>.self, using: decoder)
                    if serverRes.status == 0 {
                        if let model = serverRes.data {
                            completion?(.success(model))
                        } else {
                            print("data数据解析失败")
                            completion?(.error(ZCNetworkError(errorCode: -1, errorMessage: "data数据解析失败")))
                        }
                    } else {
                        var hcError = ZCNetworkError()
                        hudMessage = self._errorHandle(code: serverRes.status ?? -1, msg: serverRes.error ?? "")
                        api.errorCodeProcess(errorMsg: (serverRes.status ?? -1, serverRes.error ?? ""))
                        if let code = serverRes.status {
                            hcError.errorCode = code
                        }
                        if let message = serverRes.error {
                            hcError.errorMessage = message
                        }
                        completion?(.error(hcError))
                        let traceId = (response.response?.allHeaderFields["X-Trace-Id"] as? String) ?? ""
                        print("接口报错>>api>>\(api.path)>> X-Trace-Id: \(traceId) \n\(serverRes.error ?? "")")
                    }
                } catch {
                    if case let MoyaError.objectMapping(sError, _) = error {
                        let text = "数据解析失败: -> \(api.identifier) -- \(self.decodingErrorDescription(sError)) \n接口响应：\(String(describing: String(data: response.data, encoding: .utf8) ?? response.response?.description))"
                        print(text)
                        } else {
                            print(error.localizedDescription)
                        }
                        
                        var hcError = ZCNetworkError()
                        hcError.errorCode = -1
                        hcError.errorMessage = ""
                        DispatchQueue.main.async {
                        completion?(.error(hcError))
                    }
                }
                if let serverRes = try? response.map(ZCResponseModel<T>.self) {
                    if serverRes.status == 1, let model = serverRes.data {
                        completion?(.success(model))
                    }
                }
                
            case .failure(let error):
                
                switch error {
                case let MoyaError.underlying(error, response):
                    if let response = response {
                        print("服务器错误，statusCode：\(response.statusCode)")
                    } else {
                        switch (error as NSError).code {
                        case NSURLErrorNotConnectedToInternet:
                            // "网络连接已断开，请检查Wi-Fi和蜂窝网络"
                            // 错误host 13
                            break
                        case NSURLErrorDNSLookupFailed, 13:
                            // "网络连接失败！请检查DNS设置"
                            print("网络连接失败！请检查DNS设置")
                        case NSURLErrorTimedOut:
                            // "网络连接超时，请靠近Wi-Fi和蜂窝网络"
                            hudMessage = "请求超时"// LanguageManager.shared.__Loc(target: )
                        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                            print("无法连接服务器")
                        default:
                            break
                        }
                    }
                    
                case let MoyaError.statusCode(response):
                    print("服务器错误，statusCode：\(response.statusCode)")
                case let MoyaError.objectMapping(error, response):
                    let text = "数据解析失败: -> \(api.identifier) -- \(self.decodingErrorDescription(error)) \n接口响应：\(String(data: response.data, encoding: .utf8) ?? "")"
                    print(text)
                default:
                    print(error.localizedDescription)
                }
                
                var hcError = ZCNetworkError()
                hcError.errorCode = -1
                hcError.errorMessage = hudMessage
                DispatchQueue.main.async {
                    completion?(.error(hcError))
                }
            }
            
            if !hudMessage.isEmpty {
                print(hudMessage)
            }
        }
        
        return ZCNetworkTask(identifier: api.identifier, wrapper: wrapper)
    }

    private func _errorHandle(code: Int, msg: String) -> String {
        self.generalErrorCallBack?(code, msg)
        var tip = msg
        switch code {
        default:
            break
        }
        return tip
    }
    
    func decodingErrorDescription(_ error: Error) -> String {
        var text = "未知解析错误"
        switch error {
        case DecodingError.dataCorrupted(let ctx):
            let keyPath = ctx.codingPath.compactMap { return $0.stringValue }.joined(separator: ".")
            text = "[Error]: dataCorrupted!! \n[keyPath]: \(keyPath)\n[Description]:\(ctx.debugDescription)"
            
        case let DecodingError.keyNotFound(_, ctx):
            
            let keyPath = ctx.codingPath.compactMap { return $0.stringValue }.joined(separator: ".")
            text = "[Error]: keyNotFound!! \n[keyPath]: \(keyPath)\n[Description]:\(ctx.debugDescription)"
            
        case let DecodingError.typeMismatch(_, ctx):
            let keyPath = ctx.codingPath.compactMap { return $0.stringValue }.joined(separator: ".")
            text = "[Error]: typeMismatch!! \n[keyPath]: \(keyPath)\n[Description]:\(ctx.debugDescription)"
            
        case let DecodingError.valueNotFound(_, ctx):
            let keyPath = ctx.codingPath.compactMap { return $0.stringValue }.joined(separator: ".")
            text = "[Error]: valueNotFound!! \n[keyPath]: \(keyPath)\n[Description]:\(ctx.debugDescription)"
            
        default:
            break
        }
        
        return text
    }
}
