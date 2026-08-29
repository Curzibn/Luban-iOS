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

压缩策略与 Android 主库逐分支一致：

- 短边基准 1440 的尺寸收缩，长图墙、超大像素陷阱与千万像素上限逐分支对齐
- 非长图固定质量 60 输出；长图按估算目标大小二分搜索最优质量，兜底质量 5
- EXIF 方向自动转正；压缩结果大于原图时自动回退原图，不劣化
- 多图并发压缩，结果与输入顺序一一对应
- 输出字节数因平台 JPEG 编码器实现（Apple ImageIO / libjpeg-turbo）而与 Android 存在正常差异

# ☕ 捐助

如果这个项目对您有帮助，欢迎通过以下方式支持我的工作。您的支持是我持续改进和维护这个项目的动力。

<div align="center">

<table>
<tr>
<td align="center">
<img src="images/alipay.png" width="300" alt="支付宝收款码" />
</td>
<td width="50"></td>
<td align="center">
<img src="images/wechat.png" width="300" alt="微信收款码" />
</td>
</tr>
</table>

</div>

感谢您的支持！🙏

## License

Apache License 2.0，与主库一致。
