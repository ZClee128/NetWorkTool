
import Foundation

public enum ZCRequestLoginPolicy: Int {
    case soft = 1 // 判断用户登录，不管判断结果如何，继续服务（如果登录，服务带登录信息到服务端）
    case needLogin = 2  // 判断用户登录，已登，服务继续。未登，弹出登录
//    case checkLoginWithAutoLogin = 3 //判断用户登录，并尝试自动登录。结果：已登，服务继续。未登，服务失败
//    case checkLoginWithAutoAndManualLogin = 4 //判断用户登录，并尝试自动登录，都不行弹出登录界面。结果：已登，服务继续。未登，服务失败
//    case checkLoginWithManualLogin = 5 //判断用户登录，未登则弹出登录界面。结果：已登，服务继续。未登，服务失败
}

public protocol ZCApiProtocol {
    var loginPolicy: ZCRequestLoginPolicy { get }
    /// 是否展示loading
    var showLoading: Bool { get }
    /// 是否提示错误消息  网络错误 | 接口返回的错误消息
    var showErrorMessage: Bool { get }
    /// 请求id path + params 组成
    var identifier: String { get }
    /// 错误码处理 错误码 | 错误信息
    func errorCodeProcess(errorMsg: (Int, String))
}
