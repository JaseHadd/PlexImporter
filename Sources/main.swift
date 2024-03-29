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

func processFile(withURL url: URL) -> Bool {
    let mediaExtensions = ["webm", "mkv", "flv", "vog", "ogv", "avi", "mov", "qt", "wmv", "yuv", "rm", "rmvb", "amv", "mp4", "m4p", "m4v", "mpg", "mp2", "mpeg", "mpe", "mpv", "m2v", "m4v", "3gpp", "3gpp2", "flv", "f4v", "f4p", "f4a", "f4b", "srt"]
    let targetDirectory = URL(fileURLWithPath: "/var/lib/plexmediaserver/TV Shows", isDirectory: true)
    let regex = try! NSRegularExpression(pattern: "([^/]*)[. ][Ss](\\d{1,2})[Ee](\\d{1,2})", options: [])
    
    let fileManager = FileManager.default
    
    if mediaExtensions.contains(url.pathExtension) {
        let stringsToDelete = ["US", "UK"]
        let fileName = url.lastPathComponent
        let results = regex.matches(in: fileName, options: .init(rawValue: 0), range: NSMakeRange(0, fileName.utf16.count))
        
        if results.count == 0 { return false; }
        
        #if os(OSX) || os(iOS)
            var showName = fileName.substring(with: fileName.range(from: results[0].rangeAt(1))!)
            let seasonNumber = fileName.substring(with: fileName.range(from: results[0].rangeAt(2))!)
            let episodeNumber = fileName.substring(with: fileName.range(from: results[0].rangeAt(3))!)
        #else
            var showName = fileName.substring(with: fileName.range(from: results[0].range(at: 1))!)
            let seasonNumber = fileName.substring(with: fileName.range(from: results[0].range(at: 2))!)
            let episodeNumber = fileName.substring(with: fileName.range(from: results[0].range(at: 3))!)
        #endif
        
        showName = showName.replacingOccurrences(of: "([^A-Z])\\.([\\w\\d])", with: "$1 $2", options: .regularExpression, range: nil)
        showName = showName.replacingOccurrences(of: "(\\d{4})", with: "($1)", options: .regularExpression, range: nil)
        
        showName.components(separatedBy: " ").filter { $0.hasSuffix("s") }.forEach { word in
            var wordWithApostrophe = word
            wordWithApostrophe.insert("'", at: wordWithApostrophe.index(before: wordWithApostrophe.endIndex))
            
            let newShowName = showName.replacingOccurrences(of: word, with: wordWithApostrophe)
            if fileManager.fileExists(atPath: targetDirectory.appendingPathComponent(newShowName).path) {
                showName = newShowName
            }
        }
        
        let targetPath = "\(showName)/Season \(seasonNumber)"
        let targetFile = "\(showName) - s\(seasonNumber)e\(episodeNumber).\(url.pathExtension)"
        
        let seasonDirectory = getDirectoryURL(path: targetPath, relativeTo: targetDirectory)
        let targetURL = seasonDirectory.appendingPathComponent(targetFile)
        
        if fileManager.fileExists(atPath: targetURL.path) {
            print("Deleting original item")
            if let _ = try? fileManager.removeItem(at: targetURL) {
                print("Success")
            }
        }
        print("Moving episode to ", targetURL.path)
        if let _ = try? fileManager.moveItem(at: url, to: targetURL) {
            print("Moved episode to ", targetURL.path)
        }
        else {
            print("Unable to move episode");
        }
        
    }
    
    else if url.deletingLastPathComponent().lastPathComponent.range(of: regex.pattern, options: .regularExpression, range: nil, locale: nil) != nil {
        if let _ = try? fileManager.removeItem(at: url) {
            print("Deleted ", url.path)
        } else {
            print("Tried to delete file, but failed: ", url.path)
        }
    }
    
    else {
        print("Skipping episode: ", url.path)
        return false;
    }
    return true;
}

let basePath = "/var/lib/transmission-daemon/downloads/"
let test = runCommand(cmd: "/usr/bin/transmission-remote", args: "-l");
for outputLine in test.output {
    var delete = false
    let components = outputLine.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    if components.count < 5 || components[4] != "Done" { continue }
    
    guard let id = components.first else { continue }
    
    let name = components.suffix(from: 9) .joined(separator: " ")
    
    let fileManager = FileManager.default
    let torrentURL = URL(fileURLWithPath: basePath.appending(name))
    
    if let files = try? fileManager.contentsOfDirectory(at: torrentURL, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) {
        files.forEach { file in if(processFile(withURL: file)) { delete = true } }
    }
    else if(fileManager.fileExists(atPath: torrentURL.path)) {
        delete = processFile(withURL: torrentURL)
    }
    else {
        print("Error processing", name, ": couldn't find file.")
    }
    
    runCommand(cmd: "/usr/bin/transmission-remote", args: "--torrent", id, "--remove")
    if delete {
        try? fileManager.removeItem(at: torrentURL)
    }
    
    // ugh. if file exists ... if file, else if directory ... also have to update other script because it's adding them every hour no matter what.
}
