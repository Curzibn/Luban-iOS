# Luban iOS

Luban for iOS —— Swift 图片压缩库，像素级还原微信朋友圈压缩策略。

与 [Luban](https://github.com/Curzibn/Luban)（Android）、[flutter_luban](https://github.com/Curzibn/flutter_luban)（Flutter）同源，复用同一套自适应统一图像压缩算法体系。

## 安装

Xcode 项目通过 Swift Package Manager 引用本仓库 URL，或在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/Curzibn/Luban-iOS.git", from: "0.1.0")
]
```

支持 iOS 13+ / macOS 10.15+。

## 使用

```swift
import Luban

let outputURL = try await Luban.compress(inputURL, toDirectory: cacheDirectory)

let data = try await Luban.compress(imageData, to: outputURL)

let results = await Luban.compress(inputURLs, toDirectory: cacheDirectory)
```

压缩策略与 Android 主库完全一致：

- 短边基准 1440 的尺寸收缩，长图墙、超大像素陷阱与千万像素上限逐分支对齐
- 非长图固定质量 60 输出；长图按估算目标大小二分搜索最优质量，兜底质量 5
- EXIF 方向自动转正；压缩结果大于原图时自动回退原图，不劣化
- 多图并发压缩，Swift Concurrency 原生接口

## License

Apache License 2.0，与主库一致。
