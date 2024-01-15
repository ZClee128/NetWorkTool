import UIKit

public struct ZCNetworkError: Error, Equatable {
    public static func == (lhs: ZCNetworkError, rhs: ZCNetworkError) -> Bool {
        return lhs.errorCode == rhs.errorCode
    }
    /// 后端错误码
    public var errorCode: Int = -1
    /// 后端错误提示消息
    public var errorMessage: String = ""
    
    public  init(errorCode: Int = -1, errorMessage: String = "") {
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}
