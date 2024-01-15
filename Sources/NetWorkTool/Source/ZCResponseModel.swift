import UIKit


public struct ZCEmpty: Codable {}

public enum ZCResult<T, E> {
    case success(T)
    case error(E)
}

class ZCResponseModel<T: Decodable>: Decodable {
    /**0|非0,integer*/
    var status: Int?
    var data: T?
    /**状态码说明，status =0 时，才有此字段返回，状态码说明参考错误码表*/
    var error: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case data
        case error
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        status = try values.decodeIfPresent(Int.self, forKey: .status)
        error = try values.decodeIfPresent(String.self, forKey: .error)
        do {
            if T.self == ZCEmpty.self {
                self.data = ZCEmpty() as? T
            } else if T.self == String.self {
                self.data = try values.decodeIfPresent(String.self, forKey: .data) as? T
            } else {
                self.data = try values.decodeIfPresent(T.self, forKey: .data)
            }
        
        } catch {
            throw error
        }
    }
}

public struct ZCForbiddenDataModel: Decodable {
    public var uid: String?
    public var error: String?
    public var expires_time: String?
}


