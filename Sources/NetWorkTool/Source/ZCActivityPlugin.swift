
import Foundation
import Moya

/// 全局loading控制，短时间内快速响应的接口不做loading
class ZCActivityPlugin {
    private let maxCount = 3
    private var isLoading = false
    private var loadingPaths: Set<String> = []
    
    private func checkLoading(with path: String) {
        if loadingPaths.contains(path) && !isLoading {
            print("请求活动：loading...\(path):-\(Date().timeIntervalSince1970)")
            ZCNetwork.shared.showLoadingBlock?()
            self.isLoading = true
        }
    }
    
    private func endLoading(with path: String) {
        loadingPaths.remove(path)
        if loadingPaths.isEmpty && isLoading {
            WGNetwork.shared.hideLoadingBlock?()
            self.isLoading = false
        }
    }
}

extension ZCActivityPlugin: PluginType {
    
    func willSend(_ request: RequestType, target: TargetType) {
        guard let type = target as? MultiTarget, let api = type.target as? WEApiProtocol else { return }
        // 粗糙清空
        if loadingPaths.count > maxCount {
            loadingPaths.removeAll()
        }
        if api.showLoading {
            loadingPaths.insert(target.path)
        }
//        Logger.print("请求活动开始：\(target.path):-\(Date().timeIntervalSince1970)")
        wg_delay(by: 0.7) {
            self.checkLoading(with: target.path)
        }
    }
    
    func didReceive(_ result: Result<Moya.Response, MoyaError>, target: TargetType) {
//        Logger.print("请求活动结束：\(target.path)")
        self.endLoading(with: target.path)
    }
}
