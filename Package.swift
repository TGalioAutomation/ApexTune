// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOptimizer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AppUninstaller", targets: ["AppUninstaller"]),
        .executable(name: "AIModelKitVerify", targets: ["AIModelKitVerify"])
    ],
    targets: [
        .target(
            name: "AIModelKit",
            path: "Sources/AIModelKit"
        ),
        .executableTarget(
            name: "AIModelKitVerify",
            dependencies: ["AIModelKit"],
            path: "Sources/AIModelKitVerify"
        ),
        .executableTarget(
            name: "MacOptimizerWidget",
            path: "WidgetExtension",
            exclude: ["Info.plist"]
        ),
        .executableTarget(
            name: "AppUninstaller",
            dependencies: ["AIModelKit"],
            path: "AppUninstaller",
            exclude: [
                "Info.plist",
                "compile_errors.txt",
                "BrandAssets",
                "yibiaopan_2026.png",
                "yinpan_2026.png",
                "zhiwendunpai_2026.png"
            ],
            resources: [
                .copy("Languages"),
                .process("AppIcon.icns"),
                .process("ButtonClick.m4a"),
                .process("CleanDidFinish-Winter.m4a"),
                .process("CleanDidFinish.m4a"),
                .process("Intro.mp4"),
                .process("Uninstaller.jpg"),
                .process("Uninstaller@2x.jpg"),
                .process("appuploader.png"),
                .process("clean-up.866fafd0.png"),
                .process("deepclean_app_residue.png"),
                .process("deepclean_cache_files.png"),
                .process("deepclean_large_files.png"),
                .process("deepclean_log_files.png"),
                .process("deepclean_system_junk.png"),
                .process("feizhilou.png"),
                .process("kongjianshentou copy.png"),
                .process("kongjianshentou.png"),
                .process("malware@2x.png"),
                .process("protection.80f7790f.png"),
                .process("resubscribe_welcome.png"),
                .process("resubscribe_welcome@2x.png"),
                .process("resource/yibiaopan_2026.png"),
                .process("resource/yinpan_2026.png"),
                .process("resource/zhiwendunpai_2026.png"),
                .process("shenduqingli.png"),
                .process("smart-scan.2f4ddf59.png"),
                .process("system-junk-mouse.png"),
                .process("system_clean_menu.png"),
                .process("welcome.icns"),
                .process("welcome.png"),
                .process("yinsi.png"),
                .process("youhua.png")
            ]
        ),
        .testTarget(
            name: "AppUninstallerTests",
            dependencies: ["AIModelKit"]
        )
    ]
)
