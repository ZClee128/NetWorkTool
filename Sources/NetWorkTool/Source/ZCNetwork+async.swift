
import Foundation
import Moya

public extension ZCNetwork {
    func requestAsync<D:Decodable>(api: TargetType & ZCApiProtocol) async -> ZCResult<D,ZCNetworkError> {
         await withCheckedContinuation { continuation in
            self.request(api: api) { (result: WEResult<D,WGNetworkError>) in
                continuation.resume(returning: result)
            }
        }
    }
}
