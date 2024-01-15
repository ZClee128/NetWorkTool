

import Foundation
import Moya
import Alamofire

public struct MetricsTime {
    public var httpTime: Double = 0
    public var domainTime: Double = 0
    public var requesTime: Double = 0
    public var responseTime: Double = 0
    /// 协议名称
    var networkProtocolName: String = ""
    /// 是否使用代理
    var isProxyConnection: Bool = false
    /// 是否复用已有连接
    var isReusedConnection: Bool = false
    
    public init(httpTime: Double, domainTime: Double, requesTime: Double, responseTime: Double, networkProtocolName: String, isProxyConnection: Bool, isReusedConnection: Bool) {
        self.httpTime = httpTime
        self.domainTime = domainTime
        self.requesTime = requesTime
        self.responseTime = responseTime
        self.networkProtocolName = networkProtocolName
        self.isProxyConnection = isProxyConnection
        self.isReusedConnection = isReusedConnection
    }
}

public class MoyaConfig {
    
    public static let shared = MoyaConfig()
    private var httpReqMap: [String: [MetricsTime]] = [:]
    
    lazy var monitor: ClosureEventMonitor = {
        let monitor = ClosureEventMonitor()
        monitor.taskDidFinishCollectingMetrics = {[weak self] _, task, metrics in
            guard let `self` = self else { return }
            for item in metrics.transactionMetrics {
                var httpTime: Double = 0
                var domainTime: Double = 0
                if let connectEndDate = item.connectEndDate,
                   let connectStartDate = item.connectStartDate {
                    httpTime = connectEndDate.timeIntervalSince(connectStartDate) * 1000
                }
                if let domainLookupStartDate = item.domainLookupStartDate,
                   let domainLookupEndDate = item.domainLookupEndDate {
                    domainTime = domainLookupEndDate.timeIntervalSince(domainLookupStartDate) * 1000
                }
                if let requestStartDate = item.requestStartDate,
                   let requestEndDate = item.requestEndDate,
                   let responseStartDate = item.responseStartDate,
                   let responseEndDate = item.responseEndDate {
                    if self.httpReqMap["\(item.request.url?.absoluteString ?? "")"] != nil {
                        var list = self.httpReqMap["\(item.request.url?.absoluteString ?? "")"]
                        list?.append(MetricsTime(httpTime: httpTime, domainTime: domainTime, requesTime: requestEndDate.timeIntervalSince(requestStartDate) * 1000, responseTime: responseEndDate.timeIntervalSince(responseStartDate) * 1000, networkProtocolName: item.networkProtocolName ?? "", isProxyConnection: item.isProxyConnection, isReusedConnection: item.isReusedConnection))
                        self.httpReqMap["\(item.request.url?.absoluteString ?? "")"] = list
                    } else {
                        self.httpReqMap["\(item.request.url?.absoluteString ?? "")"] = [MetricsTime(httpTime: httpTime, domainTime: domainTime, requesTime: requestEndDate.timeIntervalSince(requestStartDate) * 1000, responseTime: responseEndDate.timeIntervalSince(responseStartDate) * 1000, networkProtocolName: item.networkProtocolName ?? "", isProxyConnection: item.isProxyConnection, isReusedConnection: item.isReusedConnection)]
                    }
                }
            }
        }
        monitor.taskDidComplete = { _, task, _ in
            let list = self.httpReqMap["\(task.originalRequest?.url?.absoluteString ?? "")"]
            var httpTime: Double = 0
            var domainTime: Double = 0
            var requesTime: Double = 0
            var responseTime: Double = 0
            /// 协议名称
            var networkProtocolName: String = ""
            /// 是否使用代理
            var isProxyConnection: Bool = false
            /// 是否复用已有连接
            var isReusedConnection: Bool = false
            for item in list ?? [] {
                httpTime += item.httpTime
                domainTime += item.domainTime
                requesTime += item.requesTime
                responseTime += item.responseTime
                networkProtocolName = item.networkProtocolName
                isProxyConnection = item.isProxyConnection
                isReusedConnection = item.isReusedConnection
            }

            if let error = task.error  {
                print(">>>>api:\(task.originalRequest?.url?.absoluteString ?? "")\nerror>>>>\(error)")
            }
            if httpTime > 0 || domainTime > 0 {
                print(">>>>api:\(task.originalRequest?.url?.absoluteString ?? "")\n>>>>https建立连接时间:\(httpTime.decimalString(2))ms\n>>>>DNS解析时间:\(domainTime.decimalString(2))ms\n>>>>请求时间:\(requesTime.decimalString(2))ms\n>>>>响应时间:\(responseTime.decimalString(2))ms\n>>>>协议名称: \(networkProtocolName)\n>>>>是否使用代理: \(isProxyConnection)\n>>>>是否复用已有连接: \(isReusedConnection)\n")
            }
            self.httpReqMap.removeValue(forKey: "\(task.originalRequest?.url?.absoluteString ?? "")")
        }
        return monitor
    }()

    static let apiSession: Session = {
        let configuration = URLSessionConfiguration.default
        let session = Session(configuration: configuration, startRequestsImmediately: false, eventMonitors: [MoyaConfig.shared.monitor])
        return session
    }()
}
