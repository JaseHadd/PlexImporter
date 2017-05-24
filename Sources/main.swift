import Foundation

extension String {
    func range(from nsRange : NSRange) -> Range<String.Index>? {
        let from16 = utf16.startIndex.advanced(by: nsRange.location)
        let to16 = from16.advanced(by: nsRange.length)
        if let from = String.Index(from16, within: self),
            let to = String.Index(to16, within: self) {
            return from ..< to
        }
        return nil
    }
}

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

func getDirectoryURL(path: String, relativeTo url: URL) -> URL {
    var newURL = url
    path.components(separatedBy: "/").forEach { newURL.appendPathComponent($0) }
    
    if !FileManager.default.fileExists(atPath: newURL.path) {
        try! FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    return newURL
}

func processFile(withURL url: URL) {
    let videoExtensions = [".webm", ".mkv", ".flv", ".vog", ".ogv", ".avi", ".mov", ".qt", ".wmv", ".yuv", ".rm", ".rmvb", ".amv", ".mp4", ".m4p", ".m4v", ".mpg", ".mp2", ".mpeg", ".mpe", ".mpv", ".m2v", ".m4v", ".3gpp", ".3gpp2", ".flv", ".f4v", ".f4p", ".f4a", ".f4b"]
    let targetDirectory = URL(fileURLWithPath: "/var/lib/plexmediaserver/", isDirectory: true)
    
    if videoExtensions.contains(url.pathExtension) {
        let stringsToDelete = ["US", "UK"]
        
        let fileManager = FileManager.default
        let fileName = url.lastPathComponent
        let regex = try! NSRegularExpression(pattern: "([^/]*)[. ][Ss](\\d{1,2})[Ee](\\d{1,2}).*\\.([\\w\\d]{3,4})", options: [])
        let results = regex.matches(in: fileName, options: .init(rawValue: 0), range: NSMakeRange(0, fileName.utf16.count))
        
        #if os(OSX) || os(iOS)
            var showName = fileName.substring(with: fileName.range(from: results[0].rangeAt(1))!)
            let seasonNumber = fileName.substring(with: fileName.range(from: results[0].rangeAt(2))!)
            let episodeNumber = fileName.substring(with: fileName.range(from: results[0].rangeAt(3))!)
        #else
            var showName = fileName.substring(with: fileName.range(from: results[0].range(at: 1))!)
            let seasonNumber = fileName.substring(with: fileName.range(from: results[0].range(at: 2))!)
            let episodeNumber = fileName.substring(with: fileName.range(from: results[0].range(at: 3))!)
        #endif
        
        showName = showName.replacingOccurrences(of: ".", with: " ", options: .init(rawValue: 0), range: nil)
        showName = showName.replacingOccurrences(of: "\\d{4}", with: "($1)", options: .regularExpression, range: nil)
        showName = showName.components(separatedBy: " ").joined(separator: " ")
        
        let targetPath = "\(showName)/Season \(seasonNumber)"
        let targetFile = "\(showName) - s\(seasonNumber)e\(episodeNumber).\(url.pathExtension)"
        
        let seasonDirectory = getDirectoryURL(path: targetPath, relativeTo: targetDirectory)
        
        print("Candidate:", seasonDirectory.path, targetFile, separator: " ")
        
        
        
//        ([^/]*)[. ][Ss](\d{1,2})[Ee](\d{1,2}).*\.([\w\d]{3,4})
    }
}

let basePath = "/var/lib/transmission-daemon/downloads/"
let test = runCommand(cmd: "/usr/bin/transmission-remote", args: "-l");
for outputLine in test.output {
    let components = outputLine.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    if components.count < 5 || components[4] != "Done" { continue }
    
    guard let id = components.first, let name = components.last else { continue }
    
    let fileManager = FileManager.default
    let torrentURL = URL(fileURLWithPath: basePath.appending(name))
    
    if let files = try? fileManager.contentsOfDirectory(at: torrentURL, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) {
        files.forEach { file in processFile(withURL: file) }
    }
    else if(fileManager.fileExists(atPath: torrentURL.path)) {
        processFile(withURL: torrentURL)
    }
    else {
        print("Error processing", name, ": couldn't find file.")
    }
    
    // ugh. if file exists ... if file, else if directory ... also have to update other script because it's adding them every hour no matter what.
}
