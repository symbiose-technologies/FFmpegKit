import Foundation
@main struct Build {}

#if canImport(PackagePlugin)
import PackagePlugin
extension Build: CommandPlugin {
    /// swift package --allow-writing-to-directory /usr/local/ --allow-writing-to-directory ~/Library/ BuildFFmpeg enable-openssl
    /// swift package  BuildFFmpeg enable-openssl
    func performCommand(context _: PluginContext, arguments: [String]) throws {
        try Build.performCommand(arguments: arguments)
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin
extension Build: XcodeCommandPlugin {
    func performCommand(context _: XcodePluginContext, arguments: [String]) throws {
        try Build.performCommand(arguments: arguments)
    }
}
#endif

#else
extension Build {
    static func main() throws {
        // swift run BuildFFmpeg --enable-openssl
        try performCommand(arguments: Array(CommandLine.arguments.dropFirst()))
    }
}
#endif

extension Build {
    static var ffmpegConfiguers = [String]()
    /// enable-libsrt depend enable-openssl
    /// enable-libass depend enable-libfreetype enable-libfribidi enable-libharfbuzz
    /// enable-gnutls depend enable-nettle enable-gmp
    /// enable-libsmbclient depend enable-gmp enable-nettle enable-gnutls
    ///  enable-mpv depend enable-libfreetype enable-libfribidi enable-libharfbuzz enable-libass
    /// - Parameter arguments: enable-openssl enable-libsrt enable-libfreetype enable-libfribidi enable-libharfbuzz enable-libass enable-gmp enable-nettle enable-gnutls enable-libsmbclient disable-ffmpeg enable-mpv enable-debug platform=macos
    static func performCommand(arguments: [String]) throws {
        print(arguments)
        if Utility.shell("which brew") == nil {
            print("""
            You need to run the script first
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            """)
            return
        }
        if Utility.shell("which pkg-config") == nil {
            Utility.shell("brew install pkg-config")
        }
        let path = URL.currentDirectory + "Script"
        if !FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        }
        FileManager.default.changeCurrentDirectoryPath(path.path)
        BaseBuild.platforms = arguments.compactMap { argument in
            if argument.hasPrefix("platform=") {
                let value = String(argument.suffix(argument.count - "platform=".count))
                return PlatformType(rawValue: value)
            } else {
                return nil
            }
        }

        var platforms = [PlatformType]()
        var librarys = [Library]()
        var disableFFmpeg = false
        var isFFmpegDebug = false
        for argument in arguments {
            if argument == "disable-ffmpeg" {
                disableFFmpeg = true
            } else if argument == "enable-debug" {
                isFFmpegDebug = true
            } else if argument.hasPrefix("platform=") {
                let value = String(argument.suffix(argument.count - "platform=".count))
                if let platform = PlatformType(rawValue: value) {
                    platforms.append(platform)
                }
            } else if argument.hasPrefix("enable-") {
                let value = String(argument.suffix(argument.count - "enable-".count))
                if let library = Library(rawValue: value) {
                    librarys.append(library)
                }
            } else if argument.hasPrefix("--") {
                Build.ffmpegConfiguers.append(argument)
            }
        }
        if isFFmpegDebug {
            Build.ffmpegConfiguers.append("--enable-debug")
            Build.ffmpegConfiguers.append("--disable-stripping")
            Build.ffmpegConfiguers.append("--disable-optimizations")
        } else {
            Build.ffmpegConfiguers.append("--disable-debug")
            Build.ffmpegConfiguers.append("--enable-stripping")
            Build.ffmpegConfiguers.append("--enable-optimizations")
        }
        if platforms.isEmpty {
            BaseBuild.platforms = PlatformType.allCases
        } else {
            BaseBuild.platforms = platforms
        }

        if !disableFFmpeg {
            librarys.append(.FFmpeg)
        }
        if let index = librarys.firstIndex(of: .mpv) {
            librarys.remove(at: index)
            librarys.append(.mpv)
        }

        for library in librarys {
            try library.build.buildALL()
        }
    }
}

private enum Library: String, CaseIterable {
    case libfreetype, libfribidi, libass, openssl, libsrt, libsmbclient, libgnutls, libgmp, FFmpeg, nettle, harfbuzz, png, mpv
    var version: String {
        switch self {
        case .FFmpeg:
            return "n5.1.2"
        case .libfreetype:
            return "VER-2-12-1"
        case .libfribidi:
            return "v1.0.12"
        case .harfbuzz:
            return "5.3.1"
        case .libass:
            return "0.17.0"
        case .png:
            return "v1.6.39"
        case .mpv:
            return "v0.35.0"
        case .openssl:
            return "openssl-3.0.7"
        case .libsrt:
            return "v1.5.1"
        case .libsmbclient:
            return "samba-4.17.5"
        case .libgnutls:
            return "3.7.8"
        case .nettle:
            return "nettle_3.8.1_release_20220727"
        case .libgmp:
            return "v6.2.1"
        }
    }

    var url: String {
        switch self {
        case .png:
            return "https://github.com/glennrp/libpng"
        case .mpv:
            return "https://github.com/\(rawValue)-player/\(rawValue)"
        case .libsrt:
            return "https://github.com/Haivision/srt"
        case .libsmbclient:
            return "https://github.com/samba-team/samba"
        case .nettle:
            return "https://github.com/gnutls/nettle"
        case .libgmp:
            return "https://github.com/alisw/GMP"
        default:
            var value = rawValue
            if self != .libass, value.hasPrefix("lib") {
                value = String(value.suffix(value.count - "lib".count))
            }
            return "https://github.com/\(value)/\(value)"
        }
    }

    var isFFmpegDependentLibrary: Bool {
        switch self {
        case .png, .harfbuzz, .nettle, .mpv, .FFmpeg:
            return false
        default:
            return true
        }
    }

    var build: BaseBuild {
        switch self {
        case .FFmpeg:
            return BuildFFMPEG()
        case .libfreetype:
            return BuildFreetype()
        case .libfribidi:
            return BuildFribidi()
        case .harfbuzz:
            return BuildHarfbuzz()
        case .libass:
            return BuildASS()
        case .png:
            return BuildPng()
        case .mpv:
            return BuildMPV()
        case .openssl:
            return BuildOpenSSL()
        case .libsrt:
            return BuildSRT()
        case .libsmbclient:
            return BuildSmbclient()
        case .libgnutls:
            return BuildGnutls()
        case .nettle:
            return BuildNettle()
        case .libgmp:
            return BuildGmp()
        }
    }
}

private class BaseBuild {
    static var platforms = PlatformType.allCases
    private let library: Library
    let directoryURL: URL
    init(library: Library) {
        self.library = library
        directoryURL = URL.currentDirectory + "\(library.rawValue)-\(library.version)"
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try! Utility.launch(path: "/usr/bin/git", arguments: ["clone", "--recurse-submodules", "--depth", "1", "--branch", library.version, library.url, directoryURL.path])
        }
    }

    func buildALL() throws {
        try? FileManager.default.removeItem(at: URL.currentDirectory + library.rawValue)
        for platform in BaseBuild.platforms {
            for arch in architectures(platform) {
                try build(platform: platform, arch: arch)
            }
        }
        try createXCFramework()
    }

    func architectures(_ platform: PlatformType) -> [ArchType] {
        platform.architectures()
    }

    func build(platform: PlatformType, arch: ArchType) throws {
        let buildURL = scratch(platform: platform, arch: arch)
        try? FileManager.default.createDirectory(at: buildURL, withIntermediateDirectories: true, attributes: nil)
        try? _ = Utility.launch(path: "/usr/bin/make", arguments: ["distclean"], currentDirectoryURL: buildURL)
        let environ = environment(platform: platform, arch: arch)
        try configure(buildURL: buildURL, environ: environ, platform: platform, arch: arch)
        try Utility.launch(path: "/usr/bin/make", arguments: ["-j5", "-s"], currentDirectoryURL: buildURL, environment: environ)
        try Utility.launch(path: "/usr/bin/make", arguments: ["-j5", "install", "-s"], currentDirectoryURL: buildURL, environment: environ)
    }

    func configure(buildURL: URL, environ: [String: String], platform: PlatformType, arch: ArchType) throws {
        let autogen = directoryURL + "autogen.sh"
        if FileManager.default.fileExists(atPath: autogen.path) {
            var environ = environ
            environ["NOCONFIGURE"] = "1"
            try Utility.launch(executableURL: autogen, arguments: [], currentDirectoryURL: directoryURL, environment: environ)
        }
        let configure = directoryURL + "configure"
        var bootstrap = directoryURL + "bootstrap"
        if !FileManager.default.fileExists(atPath: configure.path), FileManager.default.fileExists(atPath: bootstrap.path) {
            try Utility.launch(executableURL: bootstrap, arguments: [], currentDirectoryURL: directoryURL, environment: environ)
        }
        bootstrap = directoryURL + ".bootstrap"
        if !FileManager.default.fileExists(atPath: configure.path), FileManager.default.fileExists(atPath: bootstrap.path) {
            try Utility.launch(executableURL: bootstrap, arguments: [], currentDirectoryURL: directoryURL, environment: environ)
        }
        try Utility.launch(executableURL: configure, arguments: arguments(platform: platform, arch: arch), currentDirectoryURL: buildURL, environment: environ)
    }

    private func pkgConfigPath(platform: PlatformType, arch: ArchType) -> String {
        var pkgConfigPath = ""
        for lib in Library.allCases {
            let path = URL.currentDirectory + [lib.rawValue, platform.rawValue, "thin", arch.rawValue]
            if FileManager.default.fileExists(atPath: path.path) {
                pkgConfigPath += "\(path.path)/lib/pkgconfig:"
            }
        }
        return pkgConfigPath
    }

    func environment(platform: PlatformType, arch: ArchType) -> [String: String] {
        ["LC_CTYPE": "C",
         "CC": ccFlags(platform: platform, arch: arch),
         "CFLAGS": cFlags(platform: platform, arch: arch),
         "CXXFLAGS": cFlags(platform: platform, arch: arch),
         "LDFLAGS": ldFlags(platform: platform, arch: arch),
         "PKG_CONFIG_PATH": pkgConfigPath(platform: platform, arch: arch),
         "CMAKE_OSX_ARCHITECTURES": arch.rawValue]
    }

    func ccFlags(platform _: PlatformType, arch _: ArchType) -> String {
        "/usr/bin/clang "
    }

    func cFlags(platform: PlatformType, arch: ArchType) -> String {
        var cflags = "-arch " + arch.rawValue + " " + platform.deploymentTarget(arch)
        if platform == .macos || platform == .maccatalyst {
            cflags += " -fno-common"
        }
        let syslibroot = platform.isysroot()
        cflags += " -isysroot \(syslibroot)"
        if platform == .maccatalyst {
            cflags += " -iframework \(syslibroot)/System/iOSSupport/System/Library/Frameworks"
        }
        if platform == .tvos || platform == .tvsimulator {
            cflags += " -DHAVE_FORK=0"
        }
        return cflags
    }

    func ldFlags(platform: PlatformType, arch: ArchType) -> String {
        cFlags(platform: platform, arch: arch)
    }

    func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        [
            "--prefix=\(thinDir(platform: platform, arch: arch).path)",
        ]
    }

    func createXCFramework() throws {
        var frameworks: [String] = []
        if let platform = BaseBuild.platforms.first {
            if let arch = architectures(platform).first {
                let lib = thinDir(platform: platform, arch: arch) + "lib"
                let fileNames = try FileManager.default.contentsOfDirectory(atPath: lib.path)
                for fileName in fileNames {
                    if fileName.hasPrefix("lib"), fileName.hasSuffix(".a") {
                        frameworks.append("Lib" + fileName.dropFirst(3).dropLast(2))
                    }
                }
            }
        }
        for framework in frameworks {
            var arguments = ["-create-xcframework"]
            for platform in BaseBuild.platforms {
                arguments.append("-framework")
                arguments.append(try createFramework(framework: framework, platform: platform))
            }
            arguments.append("-output")
            let XCFrameworkFile = URL.currentDirectory + ["../Sources", framework + ".xcframework"]
            arguments.append(XCFrameworkFile.path)
            if FileManager.default.fileExists(atPath: XCFrameworkFile.path) {
                try FileManager.default.removeItem(at: XCFrameworkFile)
            }
            try Utility.launch(path: "/usr/bin/xcodebuild", arguments: arguments)
        }
    }

    private func createFramework(framework: String, platform: PlatformType) throws -> String {
        let frameworkDir = URL.currentDirectory + [library.rawValue, platform.rawValue, "\(framework).framework"]
        try? FileManager.default.removeItem(at: frameworkDir)
        try FileManager.default.createDirectory(at: frameworkDir, withIntermediateDirectories: true, attributes: nil)
        var arguments = ["-create"]
        for arch in architectures(platform) {
            let prefix = thinDir(platform: platform, arch: arch)
            arguments.append((prefix + ["lib", "\(framework).a"]).path)
            var headerURL: URL = prefix + "include" + framework
            if !FileManager.default.fileExists(atPath: headerURL.path) {
                headerURL = prefix + "include"
            }
            try? FileManager.default.copyItem(at: headerURL, to: frameworkDir + "Headers")
        }
        arguments.append("-output")
        arguments.append((frameworkDir + framework).path)
        try Utility.launch(path: "/usr/bin/lipo", arguments: arguments)
        try FileManager.default.createDirectory(at: frameworkDir + "Modules", withIntermediateDirectories: true, attributes: nil)
        var modulemap = """
        framework module \(framework) [system] {
            umbrella "."

        """
        frameworkExcludeHeaders(framework).forEach { header in
            modulemap += """
                exclude header "\(header).h"

            """
        }
        modulemap += """
            export *
        }
        """
        FileManager.default.createFile(atPath: frameworkDir.path + "/Modules/module.modulemap", contents: modulemap.data(using: .utf8), attributes: nil)
        createPlist(path: frameworkDir.path + "/Info.plist", name: framework, minVersion: platform.minVersion, platform: platform.sdk())
        return frameworkDir.path
    }

    func thinDir(platform: PlatformType, arch: ArchType) -> URL {
        URL.currentDirectory + [library.rawValue, platform.rawValue, "thin", arch.rawValue]
    }

    func scratch(platform: PlatformType, arch: ArchType) -> URL {
        URL.currentDirectory + [library.rawValue, platform.rawValue, "scratch", arch.rawValue]
    }

    func frameworkExcludeHeaders(_: String) -> [String] {
        []
    }

    private func createPlist(path: String, name: String, minVersion: String, platform: String) {
        let identifier = "com.kintan.ksplayer." + name
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>\(name)</string>
        <key>CFBundleIdentifier</key>
        <string>\(identifier)</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>\(name)</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>87.88.520</string>
        <key>CFBundleVersion</key>
        <string>87.88.520</string>
        <key>CFBundleSignature</key>
        <string>????</string>
        <key>MinimumOSVersion</key>
        <string>\(minVersion)</string>
        <key>CFBundleSupportedPlatforms</key>
        <array>
        <string>\(platform)</string>
        </array>
        <key>NSPrincipalClass</key>
        <string></string>
        </dict>
        </plist>
        """
        FileManager.default.createFile(atPath: path, contents: content.data(using: .utf8), attributes: nil)
    }
}

private class BuildFFMPEG: BaseBuild {
    init() {
        super.init(library: .FFmpeg)
    }

    override func build(platform: PlatformType, arch: ArchType) throws {
        try super.build(platform: platform, arch: arch)
        let prefix = thinDir(platform: platform, arch: arch)
        let buildDir = scratch(platform: platform, arch: arch)
        let lldbFile = URL.currentDirectory + "LLDBInitFile"
        if let data = FileManager.default.contents(atPath: lldbFile.path), var str = String(data: data, encoding: .utf8) {
            str.append("settings \(str.count == 0 ? "set" : "append") target.source-map \((buildDir + "src").path) \(directoryURL.path)\n")
            try str.write(toFile: lldbFile.path, atomically: true, encoding: .utf8)
        }
        try FileManager.default.copyItem(at: buildDir + "config.h", to: prefix + "include/libavutil/config.h")
        try FileManager.default.copyItem(at: buildDir + "config.h", to: prefix + "include/libavcodec/config.h")
        try FileManager.default.copyItem(at: buildDir + "config.h", to: prefix + "include/libavformat/config.h")
        try FileManager.default.copyItem(at: buildDir + "src/libavutil/getenv_utf8.h", to: prefix + "include/libavutil/getenv_utf8.h")
        try FileManager.default.copyItem(at: buildDir + "src/libavutil/libm.h", to: prefix + "include/libavutil/libm.h")
        try FileManager.default.copyItem(at: buildDir + "src/libavutil/thread.h", to: prefix + "include/libavutil/thread.h")
        try FileManager.default.copyItem(at: buildDir + "src/libavutil/intmath.h", to: prefix + "include/libavutil/intmath.h")
        try FileManager.default.copyItem(at: buildDir + "src/libavutil/mem_internal.h", to: prefix + "include/libavutil/mem_internal.h")
        try FileManager.default.copyItem(at: buildDir + "src/libavcodec/mathops.h", to: prefix + "include/libavcodec/mathops.h")
        try FileManager.default.copyItem(at: buildDir + "src/libavformat/os_support.h", to: prefix + "include/libavformat/os_support.h")
        let internalPath = prefix + "include/libavutil/internal.h"
        try FileManager.default.copyItem(at: buildDir + "src/libavutil/internal.h", to: internalPath)
        if let data = FileManager.default.contents(atPath: internalPath.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: """
            #include "timer.h"
            """, with: """
            // #include "timer.h"
            """)
            str = str.replacingOccurrences(of: "kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey", with: "kCVPixelBufferMetalCompatibilityKey")
            try str.write(toFile: internalPath.path, atomically: true, encoding: .utf8)
        }
        if platform == .macos, arch.executable() {
            let fftoolsFile = URL.currentDirectory + "../Sources/fftools"
            try? FileManager.default.removeItem(at: fftoolsFile)
            if !FileManager.default.fileExists(atPath: (fftoolsFile + "include/compat").path) {
                try FileManager.default.createDirectory(at: fftoolsFile + "include/compat", withIntermediateDirectories: true)
            }
            try FileManager.default.copyItem(at: buildDir + "src/compat/va_copy.h", to: fftoolsFile + "include/compat/va_copy.h")
            try FileManager.default.copyItem(at: buildDir + "config.h", to: fftoolsFile + "include/config.h")
            try FileManager.default.copyItem(at: buildDir + "config_components.h", to: fftoolsFile + "include/config_components.h")
            if !FileManager.default.fileExists(atPath: (fftoolsFile + "include/libavdevice").path) {
                try FileManager.default.createDirectory(at: fftoolsFile + "include/libavdevice", withIntermediateDirectories: true)
            }
            try FileManager.default.copyItem(at: buildDir + "src/libavdevice/avdevice.h", to: fftoolsFile + "include/libavdevice/avdevice.h")
            try FileManager.default.copyItem(at: buildDir + "src/libavdevice/version_major.h", to: fftoolsFile + "include/libavdevice/version_major.h")
            try FileManager.default.copyItem(at: buildDir + "src/libavdevice/version.h", to: fftoolsFile + "include/libavdevice/version.h")
            if !FileManager.default.fileExists(atPath: (fftoolsFile + "include/libpostproc").path) {
                try FileManager.default.createDirectory(at: fftoolsFile + "include/libpostproc", withIntermediateDirectories: true)
            }
            try FileManager.default.copyItem(at: buildDir + "src/libpostproc/postprocess_internal.h", to: fftoolsFile + "include/libpostproc/postprocess_internal.h")
            try FileManager.default.copyItem(at: buildDir + "src/libpostproc/postprocess.h", to: fftoolsFile + "include/libpostproc/postprocess.h")
            try FileManager.default.copyItem(at: buildDir + "src/libpostproc/version_major.h", to: fftoolsFile + "include/libpostproc/version_major.h")
            try FileManager.default.copyItem(at: buildDir + "src/libpostproc/version.h", to: fftoolsFile + "include/libpostproc/version.h")
            try FileManager.default.copyItem(at: buildDir + "src/fftools/cmdutils.c", to: fftoolsFile + "cmdutils.c")
            try FileManager.default.copyItem(at: buildDir + "src/fftools/opt_common.c", to: fftoolsFile + "opt_common.c")
            try FileManager.default.copyItem(at: buildDir + "src/fftools/cmdutils.h", to: fftoolsFile + "include/cmdutils.h")
            try FileManager.default.copyItem(at: buildDir + "src/fftools/opt_common.h", to: fftoolsFile + "include/opt_common.h")
            try FileManager.default.copyItem(at: buildDir + "src/fftools/fopen_utf8.h", to: fftoolsFile + "include/fopen_utf8.h")
            let ffplayFile = URL.currentDirectory + "../Sources/ffplay"
            try? FileManager.default.removeItem(at: ffplayFile)
            try FileManager.default.createDirectory(at: ffplayFile, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: buildDir + "src/fftools/ffplay.c", to: ffplayFile + "ffplay.c")
            let ffprobeFile = URL.currentDirectory + "../Sources/ffprobe"
            try? FileManager.default.removeItem(at: ffprobeFile)
            try FileManager.default.createDirectory(at: ffprobeFile, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: buildDir + "src/fftools/ffprobe.c", to: ffprobeFile + "ffprobe.c")
            let ffmpegFile = URL.currentDirectory + "../Sources/ffmpeg"
            try? FileManager.default.removeItem(at: ffmpegFile)
            try FileManager.default.createDirectory(at: ffmpegFile + "include", withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: buildDir + "src/fftools/ffmpeg.h", to: ffmpegFile + "include/ffmpeg.h")
            try FileManager.default.copyItem(at: buildDir + "src/fftools/ffmpeg.c", to: ffmpegFile + "ffmpeg.c")
            try FileManager.default.copyItem(at: buildDir + "src/fftools/ffmpeg_filter.c", to: ffmpegFile + "ffmpeg_filter.c")
            try FileManager.default.copyItem(at: buildDir + "src/fftools/ffmpeg_hw.c", to: ffmpegFile + "ffmpeg_hw.c")
            try FileManager.default.copyItem(at: buildDir + "src/fftools/ffmpeg_mux.c", to: ffmpegFile + "ffmpeg_mux.c")
            try FileManager.default.copyItem(at: buildDir + "src/fftools/ffmpeg_opt.c", to: ffmpegFile + "ffmpeg_opt.c")
        }
    }

    override func frameworkExcludeHeaders(_ framework: String) -> [String] {
        if framework == "Libavcodec" {
            return ["xvmc", "vdpau", "qsv", "dxva2", "d3d11va", "mathops"]
        } else if framework == "Libavutil" {
            return ["hwcontext_vulkan", "hwcontext_vdpau", "hwcontext_vaapi", "hwcontext_qsv", "hwcontext_opencl", "hwcontext_dxva2", "hwcontext_d3d11va", "hwcontext_cuda", "getenv_utf8", "intmath", "libm", "thread", "mem_internal", "internal"]
        } else if framework == "Libavformat" {
            return ["os_support"]
        } else {
            return super.frameworkExcludeHeaders(framework)
        }
    }

    override func environment(platform: PlatformType, arch: ArchType) -> [String: String] {
        var environ = super.environment(platform: platform, arch: arch)
        environ["CPPFLAGS"] = cFlags(platform: platform, arch: arch)
        return environ
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        var arguments = super.arguments(platform: platform, arch: arch)
        arguments += ffmpegConfiguers
        arguments += Build.ffmpegConfiguers
        arguments.append("--target-os=darwin")
        arguments.append("--arch=\(arch.arch())")
        arguments.append(arch.cpu())
        /**
         aacpsdsp.o), building for Mac Catalyst, but linking in object file built for
         x86_64 binaries are built without ASM support, since ASM for x86_64 is actually x86 and that confuses `xcodebuild -create-xcframework` https://stackoverflow.com/questions/58796267/building-for-macos-but-linking-in-object-file-built-for-free-standing/59103419#59103419
         */
        if platform == .maccatalyst || arch == .x86_64 {
            arguments.append("--disable-neon")
            arguments.append("--disable-asm")
        } else {
            arguments.append("--enable-neon")
            arguments.append("--enable-asm")
        }
        if platform == .macos, arch.executable() {
            arguments.append("--enable-ffplay")
            arguments.append("--enable-sdl2")
            arguments.append("--enable-encoder=aac")
            arguments.append("--enable-encoder=movtext")
            arguments.append("--enable-encoder=mpeg4")
            arguments.append("--enable-decoder=rawvideo")
            arguments.append("--enable-filter=color")
            arguments.append("--enable-filter=lut")
            arguments.append("--enable-filter=negate")
            arguments.append("--enable-filter=testsrc")
            arguments.append("--disable-avdevice")
            //            arguments.append("--enable-avdevice")
            //            arguments.append("--enable-indev=lavfi")
        } else {
            arguments.append("--disable-avdevice")
            arguments.append("--disable-programs")
        }
        //        if platform == .isimulator || platform == .tvsimulator {
        //            arguments.append("--assert-level=1")
        //        }
        for library in Library.allCases {
            let path = URL.currentDirectory + [library.rawValue, platform.rawValue, "thin", arch.rawValue]
            if FileManager.default.fileExists(atPath: path.path), library.isFFmpegDependentLibrary {
                arguments.append("--enable-\(library.rawValue)")
                if library == .libsrt {
                    arguments.append("--enable-protocol=\(library.rawValue)")
                }
            }
        }
        return arguments
    }

    override func buildALL() throws {
        if Utility.shell("which nasm") == nil {
            Utility.shell("brew install nasm")
        }
        if Utility.shell("which sdl2-config") == nil {
            Utility.shell("brew install sdl2")
        }
        let lldbFile = URL.currentDirectory + "LLDBInitFile"
        try? FileManager.default.removeItem(at: lldbFile)
        FileManager.default.createFile(atPath: lldbFile.path, contents: nil, attributes: nil)
        let path = directoryURL + "libavcodec/videotoolbox.c"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: "kCVPixelBufferOpenGLESCompatibilityKey", with: "kCVPixelBufferMetalCompatibilityKey")
            str = str.replacingOccurrences(of: "kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey", with: "kCVPixelBufferMetalCompatibilityKey")
            try str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
        try super.buildALL()
    }

    private let ffmpegConfiguers = [
        // Configuration options:
        "--disable-armv5te", "--disable-armv6", "--disable-armv6t2", "--disable-bsfs",
        "--disable-bzlib", "--disable-gray", "--disable-iconv", "--disable-linux-perf",
        "--disable-xlib", "--disable-swscale-alpha", "--disable-symver", "--disable-small",
        "--enable-cross-compile", "--enable-gpl", "--enable-libxml2", "--enable-nonfree",
        "--enable-runtime-cpudetect", "--enable-thumb", "--enable-version3", "--pkg-config-flags=--static",
        "--enable-static", "--disable-shared",
        // Documentation options:
        "--disable-doc", "--disable-htmlpages", "--disable-manpages", "--disable-podpages", "--disable-txtpages",
        // Component options:
        "--enable-avcodec", "--enable-avformat", "--enable-avutil", "--enable-network", "--enable-swresample", "--enable-swscale",
        "--disable-devices", "--disable-outdevs", "--disable-indevs", "--disable-postproc",
        // ,"--disable-pthreads"
        // ,"--disable-w32threads"
        // ,"--disable-os2threads"
        // ,"--disable-dct"
        // ,"--disable-dwt"
        // ,"--disable-lsp"
        // ,"--disable-lzo"
        // ,"--disable-mdct"
        // ,"--disable-rdft"
        // ,"--disable-fft"
        // Hardware accelerators:
        "--disable-d3d11va", "--disable-dxva2", "--disable-vaapi", "--disable-vdpau",
        "--enable-videotoolbox", "--enable-audiotoolbox",
        // Individual component options:
        // ,"--disable-everything"
        // ./configure --list-encoders
        "--disable-encoders",
        // ./configure --list-decoders
        // 用所有的decoders的话，那avcodec就会达到40MB了，指定的话，那就只要20MB。
        "--disable-decoders",
        // 视频
        "--enable-decoder=av1", "--enable-decoder=dca", "--enable-decoder=flv", "--enable-decoder=h263",
        "--enable-decoder=h263i", "--enable-decoder=h263p", "--enable-decoder=h264", "--enable-decoder=hevc",
        "--enable-decoder=mjpeg", "--enable-decoder=mjpegb", "--enable-decoder=mpeg1video", "--enable-decoder=mpeg2video",
        "--enable-decoder=mpeg4", "--enable-decoder=mpegvideo", "--enable-decoder=rv30", "--enable-decoder=rv40",
        "--enable-decoder=tscc", "--enable-decoder=wmv1", "--enable-decoder=wmv2", "--enable-decoder=wmv3",
        "--enable-decoder=vc1", "--enable-decoder=vp6", "--enable-decoder=vp6a", "--enable-decoder=vp6f",
        "--enable-decoder=vp7", "--enable-decoder=vp8", "--enable-decoder=vp9",
        // 音频
        "--enable-decoder=aac*", "--enable-decoder=ac3*", "--enable-decoder=alac*",
        "--enable-decoder=amr*", "--enable-decoder=ape", "--enable-decoder=cook",
        "--enable-decoder=dca", "--enable-decoder=dolby_e", "--enable-decoder=eac3*", "--enable-decoder=flac",
        "--enable-decoder=mp1*", "--enable-decoder=mp2*", "--enable-decoder=mp3*", "--enable-decoder=opus",
        "--enable-decoder=pcm*", "--enable-decoder=truehd", "--enable-decoder=vorbis", "--enable-decoder=wma*",
        // 字幕
        "--enable-decoder=ass", "--enable-decoder=ccaption", "--enable-decoder=dvbsub", "--enable-decoder=dvdsub", "--enable-decoder=movtext",
        "--enable-decoder=pgssub", "--enable-decoder=srt", "--enable-decoder=ssa", "--enable-decoder=subrip",
        "--enable-decoder=webvtt",
        // ./configure --list-muxers
        "--disable-muxers",
        "--enable-muxer=dash", "--enable-muxer=hevc", "--enable-muxer=mp4", "--enable-muxer=m4v", "--enable-muxer=mov",
        "--enable-muxer=mpegts", "--enable-muxer=webm*",
        // ./configure --list-demuxers
        // 用所有的demuxers的话，那avformat就会达到8MB了，指定的话，那就只要4MB。
        "--disable-demuxers",
        "--enable-demuxer=aac", "--enable-demuxer=ac3", "--enable-demuxer=aiff", "--enable-demuxer=amr",
        "--enable-demuxer=ape", "--enable-demuxer=asf", "--enable-demuxer=ass", "--enable-demuxer=avi", "--enable-demuxer=caf",
        "--enable-demuxer=concat", "--enable-demuxer=dash", "--enable-demuxer=data", "--enable-demuxer=eac3",
        "--enable-demuxer=flac", "--enable-demuxer=flv", "--enable-demuxer=h264", "--enable-demuxer=hevc",
        "--enable-demuxer=hls", "--enable-demuxer=live_flv", "--enable-demuxer=loas", "--enable-demuxer=m4v",
        "--enable-demuxer=matroska", "--enable-demuxer=mov", "--enable-demuxer=mp3", "--enable-demuxer=mpeg*",
        "--enable-demuxer=ogg", "--enable-demuxer=rm", "--enable-demuxer=rtsp", "--enable-demuxer=rtp", "--enable-demuxer=srt",
        "--enable-demuxer=vc1", "--enable-demuxer=wav", "--enable-demuxer=webm_dash_manifest",
        // ./configure --list-protocols
        "--enable-protocols",
        "--disable-protocol=bluray", "--disable-protocol=ffrtmpcrypt", "--disable-protocol=gopher", "--disable-protocol=icecast",
        "--disable-protocol=librtmp*", "--disable-protocol=libssh", "--disable-protocol=md5", "--disable-protocol=mmsh",
        "--disable-protocol=mmst", "--disable-protocol=sctp", "--disable-protocol=subfile", "--disable-protocol=unix",
        // ./configure --list-filters
        "--disable-filters",
        "--enable-filter=aformat", "--enable-filter=amix", "--enable-filter=anull", "--enable-filter=aresample",
        "--enable-filter=areverse", "--enable-filter=asetrate", "--enable-filter=atempo", "--enable-filter=atrim",
        "--enable-filter=bwdif", "--enable-filter=estdif", "--enable-filter=format", "--enable-filter=fps",
        "--enable-filter=hflip", "--enable-filter=hwdownload", "--enable-filter=hwmap", "--enable-filter=hwupload",
        "--enable-filter=idet", "--enable-filter=null",
        "--enable-filter=overlay", "--enable-filter=palettegen", "--enable-filter=paletteuse", "--enable-filter=pan",
        "--enable-filter=rotate", "--enable-filter=scale", "--enable-filter=setpts", "--enable-filter=transpose",
        "--enable-filter=trim", "--enable-filter=vflip", "--enable-filter=volume", "--enable-filter=w3fdif",
        "--enable-filter=yadif", "--enable-filter=yadif_videotoolbox",
    ]
}

private class BuildOpenSSL: BaseBuild {
    init() {
        super.init(library: .openssl)
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        super.arguments(platform: platform, arch: arch) +
            [
                arch == .x86_64 ? "darwin64-x86_64" : arch == .arm64e ? "iphoneos-cross" : "darwin64-arm64",
                "no-async", "no-shared", "no-dso", "no-engine", "no-tests",
            ]
    }
}

private class BuildSmbclient: BaseBuild {
    init() {
        super.init(library: .libsmbclient)
    }

    override func scratch(platform _: PlatformType, arch _: ArchType) -> URL {
        directoryURL
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        super.arguments(platform: platform, arch: arch) +
            [
                "--bundled-libraries=NONE,ldb,tdb,tevent",
                "--disable-cephfs",
                "--disable-cups",
                "--disable-iprint",
                "--disable-glusterfs",
                "--disable-python",
                "--without-acl-support",
                "--without-ad-dc",
                "--without-ads",
                "--without-ldap",
                "--without-libarchive",
                "--without-json",
                "--without-pam",
                "--without-regedit",
                "--without-syslog",
                "--without-utmp",
                "--without-winbind",
                "--without-acl-support",
                "--with-shared-modules=!vfs_snapper",
                "--with-system-mitkrb5",
                "--host=\(platform.host(arch: arch))",
            ]
    }
}

private class BuildGmp: BaseBuild {
    init() {
        super.init(library: .libgmp)
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        super.arguments(platform: platform, arch: arch) +
            [
                "--disable-maintainer-mode",
                "--disable-assembly",
                "--with-pic",
                "--enable-static",
                "--disable-shared",
                "--disable-fast-install",
                "--host=\(platform.host(arch: arch))",
                "--with-sysroot=\(platform.isysroot())",
            ]
    }
}

private class BuildNettle: BaseBuild {
    init() {
        if Utility.shell("which autoconf") == nil {
            Utility.shell("brew install autoconf")
        }
        super.init(library: .nettle)
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        let gmpPath = URL.currentDirectory + ["gmp", platform.rawValue, "thin", arch.rawValue]
        return super.arguments(platform: platform, arch: arch) +
            [
                "--with-include-path=\(gmpPath.path)/include",
                "--with-lib-path=\(gmpPath.path)/lib",
                "--disable-mini-gmp",
                "--disable-assembler",
                "--disable-openssl",
                "--disable-gcov",
                "--disable-documentation",
                "--enable-pic",
                "--enable-static",
                "--disable-shared",
                "--disable-dependency-tracking",
                "--host=\(platform.host(arch: arch))",
                arch == .arm64 || arch == .arm64e ? "--enable-arm-neon" : "--enable-x86-aesni",
            ]
    }
}

private class BuildGnutls: BaseBuild {
    init() {
        if Utility.shell("which automake") == nil {
            Utility.shell("brew install automake")
        }
        if Utility.shell("which gtkdocize") == nil {
            Utility.shell("brew install gtk-doc")
        }
        if Utility.shell("which wget") == nil {
            Utility.shell("brew install wget")
        }
        Utility.shell("brew install bison")
        super.init(library: .libgnutls)
    }

    override func environment(platform: PlatformType, arch: ArchType) -> [String: String] {
        var environ = super.environment(platform: platform, arch: arch)
        let gmpPath = URL.currentDirectory + ["gmp", platform.rawValue, "thin", arch.rawValue]
        environ["GMP_CFLAGS"] = "-I\(gmpPath.path)/include"
        environ["GMP_LIBS"] = "-L\(gmpPath.path)/lib -lgmp"
        return environ
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        super.arguments(platform: platform, arch: arch) +
            [
                "--with-included-libtasn1",
                "--with-included-unistring",
                "--without-idn",
                "--without-p11-kit",
                "--enable-hardware-acceleration",
                "--disable-openssl-compatibility",
                "--disable-code-coverage",
                "--disable-doc",
                "--disable-manpages",
                "--disable-guile",
                "--disable-tests",
                "--disable-tools",
                "--disable-maintainer-mode",
                "--disable-full-test-suite",
                "--with-pic",
                "--enable-static",
                "--disable-shared",
                "--disable-fast-install",
                "--disable-dependency-tracking",
                "--host=\(platform.host(arch: arch))",
                "--with-sysroot=\(platform.isysroot())",
            ]
    }
}

private class BuildSRT: BaseBuild {
    init() {
        super.init(library: .libsrt)
    }

    override func buildALL() throws {
        if Utility.shell("which cmake") == nil {
            Utility.shell("brew install cmake")
        }
        try super.buildALL()
    }

    override func configure(buildURL: URL, environ: [String: String], platform: PlatformType, arch: ArchType) throws {
        let thinDirPath = thinDir(platform: platform, arch: arch).path

        let arguments = [
            (directoryURL + "CMakeLists.txt").path,
            "-Wno-dev",
            "-DUSE_ENCLIB=openssl",
            "-DCMAKE_VERBOSE_MAKEFILE=0",
            "-DCMAKE_BUILD_TYPE=Release",
            "-DCMAKE_PREFIX_PATH=\(thinDirPath)",
            "-DCMAKE_INSTALL_PREFIX=\(thinDirPath)",
            "-DENABLE_STDCXX_SYNC=1",
            "-DENABLE_CXX11=1",
            "-DUSE_OPENSSL_PC=1",
            "-DENABLE_DEBUG=0",
            "-DENABLE_LOGGING=0",
            "-DENABLE_HEAVY_LOGGING=0",
            "-DENABLE_APPS=0",
            "-DENABLE_SHARED=0",
            platform == .maccatalyst ? "-DENABLE_MONOTONIC_CLOCK=0" : "-DENABLE_MONOTONIC_CLOCK=1",
        ]
        try Utility.launch(path: "/usr/local/bin/cmake", arguments: arguments, currentDirectoryURL: buildURL, environment: environ)
    }
}

private class BuildFribidi: BaseBuild {
    init() {
        super.init(library: .libfribidi)
    }

    override func configure(buildURL: URL, environ: [String: String], platform: PlatformType, arch: ArchType) throws {
        try super.configure(buildURL: buildURL, environ: environ, platform: platform, arch: arch)
        let makefile = buildURL + "Makefile"
        // DISABLE BUILDING OF doc FOLDER (doc depends on c2man which is not available on all platforms)
        if let data = FileManager.default.contents(atPath: makefile.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of: " doc ", with: " ")
            try str.write(toFile: makefile.path, atomically: true, encoding: .utf8)
        }
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        super.arguments(platform: platform, arch: arch) +
            [
                "--disable-deprecated",
                "--disable-debug",
                "--with-pic",
                "--enable-static",
                "--disable-shared",
                "--disable-fast-install",
                "--disable-dependency-tracking",
                "--host=\(platform.host(arch: arch))",
                "--with-sysroot=\(platform.isysroot())",
            ]
    }
}

private class BuildHarfbuzz: BaseBuild {
    init() {
        super.init(library: .harfbuzz)
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        super.arguments(platform: platform, arch: arch) +
            [
                "--with-glib=no",
                "--with-freetype=no",
                "--with-directwrite=no",
                "--with-pic",
                "--enable-static",
                "--disable-shared",
                "--disable-fast-install",
                "--disable-dependency-tracking",
                "--host=\(platform.host(arch: arch))",
                "--with-sysroot=\(platform.isysroot())",
            ]
    }
}

private class BuildFreetype: BaseBuild {
    init() {
        super.init(library: .libfreetype)
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        super.arguments(platform: platform, arch: arch) +
            [
                "--with-zlib",
                "--without-harfbuzz",
                "--without-bzip2",
                "--without-fsref",
                "--without-quickdraw-toolbox",
                "--without-quickdraw-carbon",
                "--without-ats",
                "--disable-mmap",
                "--with-png=no",
                "--with-pic",
                "--enable-static",
                "--disable-shared",
                "--disable-fast-install",
                "--host=\(platform.host(arch: arch))",
                "--with-sysroot=\(platform.isysroot())",
            ]
    }
}

private class BuildPng: BaseBuild {
    init() {
        super.init(library: .png)
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        let asmOptions = arch == .x86_64 ? "--enable-intel-sse=yes" : "--enable-arm-neon=yes"
        return super.arguments(platform: platform, arch: arch) +
            [
                asmOptions,
                "--disable-unversioned-libpng-pc",
                "--disable-unversioned-libpng-config",
                "--with-pic",
                "--enable-static",
                "--disable-shared",
                "--disable-fast-install",
                "--host=\(platform.host(arch: arch))",
                "--with-sysroot=\(platform.isysroot())",
            ]
    }
}

private class BuildASS: BaseBuild {
    init() {
        super.init(library: .libass)
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        // todo
//        let asmOptions = platform == .maccatalyst || arch == .x86_64 ? "--disable-asm" : "--enable-asm"
        let asmOptions = "--disable-asm"
        return super.arguments(platform: platform, arch: arch) +
            [
                "--disable-libtool-lock",
                "--disable-fontconfig",
                "--disable-require-system-font-provider",
                "--disable-test",
                "--disable-profile",
                "--disable-coretext",
                asmOptions,
                "--with-pic",
                "--enable-static",
                "--disable-shared",
                "--disable-fast-install",
                "--disable-dependency-tracking",
                "--host=\(platform.host(arch: arch))",
                "--with-sysroot=\(platform.isysroot())",
            ]
    }
}

private class BuildMPV: BaseBuild {
    init() {
        super.init(library: .mpv)
    }

    override func buildALL() throws {
        let path = directoryURL + "wscript_build.py"
        if let data = FileManager.default.contents(atPath: path.path), var str = String(data: data, encoding: .utf8) {
            str = str.replacingOccurrences(of:
                """
                "osdep/subprocess-posix.c",            "posix"
                """, with:
                """
                "osdep/subprocess-posix.c",            "posix && !tvos"
                """)
            try str.write(toFile: path.path, atomically: true, encoding: .utf8)
        }
        try super.buildALL()
    }

    override func build(platform: PlatformType, arch: ArchType) throws {
        let url = scratch(platform: platform, arch: arch)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        let environ = environment(platform: platform, arch: arch)
        try Utility.launch(executableURL: directoryURL + "bootstrap.py", arguments: [], currentDirectoryURL: directoryURL)
        try Utility.launch(path: "/usr/bin/python3", arguments: ["./waf", "distclean"], currentDirectoryURL: directoryURL, environment: environ)
        try Utility.launch(path: "/usr/bin/python3", arguments: ["./waf", "configure"] + arguments(platform: platform, arch: arch), currentDirectoryURL: directoryURL, environment: environ)
        try Utility.launch(path: "/usr/bin/python3", arguments: ["./waf", "build"], currentDirectoryURL: directoryURL, environment: environ)
        try Utility.launch(path: "/usr/bin/python3", arguments: ["./waf", "install"], currentDirectoryURL: directoryURL, environment: environ)
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        super.arguments(platform: platform, arch: arch) +
            [
                "--disable-cplayer",
                "--disable-lcms2",
                "--disable-lua",
                "--disable-rubberband",
                "--disable-zimg",
                "--disable-javascript",
                "--disable-jpeg",
                "--disable-swift",
                "--disable-vapoursynth",
                "--enable-lgpl",
                "--enable-libmpv-static",
                platform == .macos ? "--enable-videotoolbox-gl" : (platform == .maccatalyst ? "--enable-gl" : "--enable-ios-gl"),
            ]
    }

//    override func architectures(_ platform: PlatformType) -> [ArchType] {
//        if platform == .macos {
//            return [.x86_64]
//        } else {
//            return super.architectures(platform)
//        }
//    }
}

private enum PlatformType: String, CaseIterable {
    case ios, isimulator, tvos, tvsimulator, macos, maccatalyst
    var minVersion: String {
        switch self {
        case .ios, .isimulator:
            return "13.0"
        case .tvos, .tvsimulator:
            return "13.0"
        case .macos:
            return "10.15"
        case .maccatalyst:
            return "13.0"
        }
    }

    func architectures() -> [ArchType] {
        switch self {
        case .ios:
            return [.arm64, .arm64e]
        case .tvos:
            return [.arm64]
        case .isimulator, .tvsimulator:
            return [.arm64, .x86_64]
        case .macos:
            #if arch(x86_64)
            return [.x86_64, .arm64]
            #else
            return [.arm64, .x86_64]
            #endif
        case .maccatalyst:
            return [.arm64, .x86_64]
        }
    }

    func deploymentTarget(_ arch: ArchType) -> String {
        switch self {
        case .ios:
            return "-mios-version-min=\(minVersion)"
        case .isimulator:
            return "-mios-simulator-version-min=\(minVersion)"
        case .tvos:
            return "-mtvos-version-min=\(minVersion)"
        case .tvsimulator:
            return "-mtvos-simulator-version-min=\(minVersion)"
        case .macos:
            return "-mmacosx-version-min=\(minVersion)"
        case .maccatalyst:
            return arch == .x86_64 ? "-target x86_64-apple-ios-macabi" : "-target arm64-apple-ios-macabi"
        }
    }

    func sdk() -> String {
        switch self {
        case .ios:
            return "iPhoneOS"
        case .isimulator:
            return "iPhoneSimulator"
        case .tvos:
            return "AppleTVOS"
        case .tvsimulator:
            return "AppleTVSimulator"
        case .macos:
            return "MacOSX"
        case .maccatalyst:
            return "MacOSX"
        }
    }

    func isysroot() -> String {
        try! Utility.launch(path: "/usr/bin/xcrun", arguments: ["--sdk", sdk().lowercased(), "--show-sdk-path"], isOutput: true)
    }

    func host(arch: ArchType) -> String {
        switch self {
        case .ios, .isimulator, .maccatalyst:
            return "\(arch == .x86_64 ? "x86_64" : "arm64")-ios-darwin"
        case .tvos, .tvsimulator:
            return "\(arch == .x86_64 ? "x86_64" : "arm64")-tvos-darwin"
        case .macos:
            return "\(arch == .x86_64 ? "x86_64" : "arm64")-apple-darwin"
        }
    }
}

enum ArchType: String, CaseIterable {
    // swiftlint:disable identifier_name
    case arm64, x86_64, arm64e
    // swiftlint:enable identifier_name
    func executable() -> Bool {
        guard let architecture = Bundle.main.executableArchitectures?.first?.intValue else {
            return false
        }
        // NSBundleExecutableArchitectureARM64
        if architecture == 0x0100_000C, self == .arm64 {
            return true
        } else if architecture == NSBundleExecutableArchitectureX86_64, self == .x86_64 {
            return true
        }
        return false
    }

    func arch() -> String {
        switch self {
        case .arm64, .arm64e:
            return "aarch64"
        case .x86_64:
            return "x86_64"
        }
    }

    func cpu() -> String {
        switch self {
        case .arm64:
            return "--cpu=armv8"
        case .x86_64:
            return "--cpu=x86_64"
        case .arm64e:
            return "--cpu=armv8.3-a"
        }
    }
}

enum Utility {
    @discardableResult
    static func shell(_ command: String, isOutput _: Bool = false, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) -> String? {
        do {
            return try launch(executableURL: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-c", command], currentDirectoryURL: currentDirectoryURL, environment: environment)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    static func launch(path: String, arguments: [String], isOutput: Bool = false, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) throws -> String {
        try launch(executableURL: URL(fileURLWithPath: path), arguments: arguments, isOutput: isOutput, currentDirectoryURL: currentDirectoryURL, environment: environment)
    }

    @discardableResult
    static func launch(executableURL: URL, arguments: [String], isOutput: Bool = false, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) throws -> String {
        #if os(macOS)
        let task = Process()
        var environment = environment
        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/local/opt/bison/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        task.environment = environment
        var standardOutput: FileHandle?
        if isOutput {
            let pipe = Pipe()
            task.standardOutput = pipe
            standardOutput = pipe.fileHandleForReading
        } else if var logURL = currentDirectoryURL {
            logURL = logURL.appendingPathExtension("log")
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            let standardOutput = try FileHandle(forWritingTo: logURL)
            if #available(macOS 10.15.4, *) {
                try standardOutput.seekToEnd()
            }
            task.standardOutput = standardOutput
        }
        task.arguments = arguments
        var log = executableURL.path + " " + arguments.joined(separator: " ") + " environment: " + environment.description
        if let currentDirectoryURL {
            log += " url: \(currentDirectoryURL)"
        }
        print(log)
        task.currentDirectoryURL = currentDirectoryURL
        task.executableURL = executableURL
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            if isOutput, let standardOutput {
                let data = standardOutput.readDataToEndOfFile()
                let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
                print(result)
                return result
            } else {
                return ""
            }
        } else {
            throw NSError(domain: "fail", code: Int(task.terminationStatus))
        }
        #else
        return ""
        #endif
    }
}

extension URL {
    static var currentDirectory: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static func + (left: URL, right: String) -> URL {
        var url = left
        url.appendPathComponent(right)
        return url
    }

    static func + (left: URL, right: [String]) -> URL {
        var url = left
        right.forEach {
            url.appendPathComponent($0)
        }
        return url
    }
}
