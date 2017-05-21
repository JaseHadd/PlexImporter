import Foundation

func runCommand(cmd : String, args : String...) -> (output: [String], error: [String], exitCode: Int32) {
    
    var output : [String] = []
    var error : [String] = []
    
    let task = Process()
    task.launchPath = cmd
    task.arguments = args
    
    let outpipe = Pipe()
    task.standardOutput = outpipe
    let errpipe = Pipe()
    task.standardError = errpipe
    
    task.launch()
    
    let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
    if var string = String(data: outdata, encoding: .utf8) {
        string = string.trimmingCharacters(in: .newlines)
        output = string.components(separatedBy: "\n")
    }
    
    let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
    if var string = String(data: errdata, encoding: .utf8) {
        string = string.trimmingCharacters(in: .newlines)
        error = string.components(separatedBy: "\n")
    }
    
    task.waitUntilExit()
    let status = task.terminationStatus
    
    return (output, error, status)
}

let basePath = "/var/lib/transmission-daemon/downloads/"
let test = runCommand(cmd: "/usr/bin/transmission-remote", args: "-l");
for outputLine in test.output {
    let components = outputLine.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    if components.count < 5 || components[4] != "Done" { continue }
    
    guard let id = components.first, let name = components.last else { continue }
    
    var isDir: ObjCBool = false;
    let fileManager = FileManager()
    
    if fileManager.fileExists(atPath: basePath.appending(name), isDirectory: &isDir) {
        let torrentPath: String
        let filePattern: String?
        if isDir.boolValue {
            torrentPath = basePath.appending(name)
        }
        else {
            torrentPath = basePath
            filePattern = name;
        }
        
        let files = try! fileManager.contentsOfDirectory(atPath: torrentPath) // we know at this point that it IS a valid directory
        
    }
    
    // ugh. if file exists ... if file, else if directory ... also have to update other script because it's adding them every hour no matter what.
}
