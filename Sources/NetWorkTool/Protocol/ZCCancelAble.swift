
import Foundation

public protocol ZCCancelAble: AnyObject {
    var tasks: [ZCNetworkTask] { get set }
}

public extension ZCCancelAble {
    func append(task: ZCNetworkTask?) {
        guard let task = task, !task.wrapper.isCancelled else { return }
        if let sameTask = self.tasks.first(where: { $0.identifier == task.identifier }) {
            print("出现高频次相同请求，请检查代码 identifier: \(task.identifier) isCancelled: \(sameTask.wrapper.isCancelled)--")

            task.wrapper.cancel()
        } else {
            self.tasks.append(task)
        }
    }
    
    func cancelAllTasks() {
        self.tasks.forEach { (task) in
            task.wrapper.cancel()
        }
        self.tasks.removeAll()
    }
    
    func remove(task identifier: String) {
        if let index = self.tasks.firstIndex(where: { $0.identifier == identifier }) {
            self.tasks.remove(at: index)
        }
    }
}
