import Foundation
import Swifter

func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/bash"
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output
}

struct NoteTask: Codable {
    let text: String
    let file: String
    let lineNumber: Int
    let isCompleted: Bool
    
    init?(line: String) {
        let comps = line.components(separatedBy: ":")
        
        guard comps.count == 3 else { return nil }
        
        let file = comps[0]
        let lineNumStr = comps[1]
        let data = comps[2]
        
        guard
            let lineNum = Int(lineNumStr)
        else { return nil }
        
        self.file = file
        self.lineNumber = lineNum
        
        let regex = try! NSRegularExpression(pattern: "- \\[([ xX]*)\\] (.*)")
        let range = NSRange(location: 0, length: data.utf16.count)
        
        guard
            let result = regex.firstMatch(in: data, options: [], range: range),
            let doneRange = Range(result.range(at: 1), in: data),
            let titleRange = Range(result.range(at: 2), in: data)
        else { return nil }
        
        let doneStr = String(data[doneRange])
        let title = String(data[titleRange])
        let done = doneStr != " "
    
        
        self.text = title
        self.isCompleted = done
    }
}

func getTasks() -> String {
    let tasks = shell("grep -nrE \"^\\s*- \\[[ xX]{1}\\] ?(.*)\" ~/Documents/foam-notes/*")
        .components(separatedBy: "\n")
        .compactMap { NoteTask(line: $0) }

    let jsonData = try! JSONEncoder().encode(tasks)
    let json = String(data: jsonData, encoding: .utf8)!
    
    return json
}

let server = HttpServer()
server["/"] = { _ in
    .ok(.text(getTasks()))
}

do {
    try server.start()
} catch {
    print(error.localizedDescription)
}

RunLoop.main.run()
