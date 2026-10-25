# 构建 Touch-Dan

本指南只描述手动构建，不安装、重启或修改设备。构建结果与运行兼容性分别记录；真机状态见 [TESTING.md](TESTING.md)。

最后一次本机 RootHide 完整构建已通过，并已在 iPhone15,2 / iOS 16.0.2 / RootHide 上安装 Touch-Dan 0.1.0，确认 SpringBoard 与设置面板加载，以及隐根图片、偏好落盘和跨进程读取。iOS 17、长时间运行、真实录屏、多指与旋转等场景仍待验证，详见 [TESTING.md](TESTING.md)。

## 环境

- macOS 与 Xcode 命令行工具。
- Theos；RootHide 方案使用支持 RootHide 的 Theos 分支。本次采用的 RootHide/Theos 提交为 `88506b2c22e9e07dd4ed055f23c9e398a117a2c7`。
- 与选定 Xcode 编译器配套的公开 iPhoneOS SDK，默认通过 `xcrun --sdk iphoneos --show-sdk-path` 查找。最低部署版本仍为 iOS 16.0。
- Theos 下 `iPhoneOS16.5.sdk` 中的私有框架链接声明，供 Preferences、FrontBoardServices、ControlCenterUIKit 使用，以及兼容继承 Swift 二进制的 `usr/lib/swift/libswiftUIKit.tbd`。这些是链接声明，不是随包分发的实现；不使用旧 SDK 的 SwiftUI/Foundation 公开接口编译新的 Swift 工具链。
- `ldid` 等 Theos 正常构建依赖。
- 仓库中继承的 MCEmojiPicker、SwiftUIIntrospect xcframework。它们的真实源码提交/发布版本未知，不能将 plist 中的 `1.0` 视为已锁定的依赖版本。

默认 Theos 路径分别是 `$HOME/theos` 与 `$HOME/theos-roothide`，显式传入的 `THEOS` 会保留。源码不要求特定用户目录。

## 选择一种包

```sh
./devkit/build.sh rootless
./devkit/build.sh roothide
./devkit/build.sh rootful
```

上面是三个独立选项，脚本默认值为 `roothide`。需要其他 Theos 目录时，在对应命令前提供变量：

```sh
THEOS="/path/to/theos" ./devkit/build.sh rootless
THEOS="/path/to/theos-roothide" ./devkit/build.sh roothide
```

脚本会确认 Theos 的 `makefiles/common.mk` 及所需私有框架声明存在，设定 `FINALPACKAGE=1`，再执行 `make clean package`。公开 SDK 来自当前 Xcode，最低部署目标固定为 16.0。包输出到 `packages/`；不会调用 `make install`。

若当前 shell 已导出 `THEOS`，切换 rootless 和 RootHide 时也会保留这个路径。请为 RootHide 显式选用正确的 Theos 分支，或在新终端中使用默认路径。

高级路径覆盖项：`TOUCHDAN_SDK_PATH` 指向公开 SDK，`TOUCHDAN_PRIVATE_FRAMEWORKS` 指向包含私有 `.framework` 声明的目录，`TOUCHDAN_UIKIT_OVERLAY` 指向兼容的 `libswiftUIKit.tbd`。默认私有声明目录为 `$THEOS/sdks/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks`。公开 SDK 应与当前选定的 Xcode/Swift 工具链匹配；本次使用新 Swift 编译器配旧 16.5 公开 SDK 时曾遇到 SwiftUI / `os_log` 接口错误，因此将公开 SDK 与私有链接声明分开选择。

继承的 Swift 二进制引用了旧 UIKit Swift overlay 导出符号，新公开 SDK 未提供这些旧符号的链接声明，因此脚本显式加入 16.5 SDK 的 `libswiftUIKit.tbd` 兼容声明。它不替换设备上的 UIKit，也不把旧 UIKit 实现打包进去。本机链接与本次 iOS 16.0.2 组件加载均已通过，其他系统和完整交互兼容性仍待验证。

RootHide 构建使用公开的 `<roothide.h>`、`jbroot()` 与 `jbrand()`，三个组件均链接 `roothide`。不会通过包含 libroot 内部头文件绕过旧 API 的迁移错误。普通 rootful/rootless 保留各自的公开 libroot 路径适配，模拟器路径适配独立处理。

## 隐根存储

Releases 同时提供 RootHide 包（`iphoneos-arm64e`）与普通 rootless 包（`iphoneos-arm64`）。隐根存储要求仅由 RootHide 方案提供；无根包采用 `/var/jb` 安装布局及普通偏好域，已通过本机构建和包检查，尚未真机验证。rootful 仅保留源码构建选项。

- 已安装资源：通过当前 RootHide API 定位 `Library/PreferenceBundles/TDNPrefs.bundle` 和控制中心 bundle。
- 自定义图片：`<当前第二隐根>/var/mobile/Library/Touch-Dan`。
- 设置文件：`<当前第二隐根>/var/mobile/Library/Preferences/io.github.suckdrygod.touchdan.plist`，采用 RootHide 官方 Bootstrap 使用的绝对路径 suite 方式。
- 写入前校验当前隐根；解析失败、返回原系统路径或符号链接逃逸时拒绝写入，不回退真实根。
- 图片暂存与最终文件位于同一隐根目录，不使用真实 `/var/tmp` 或全局临时目录。仅清理插件自身命名的旧图片及暂存文件。

RootHide 的主隐根与 `/var` 的第二隐根可能通过符号链接关联，验证按当前越狱标识同时识别这两处官方目录，并检查第二隐根指回主隐根的链接。图片文件操作使用同目录暂存及重命名，并拒绝跟随图片目录或叶子文件的符号链接。

绝对 plist suite 的主机隔离测试仍报告 `UNVERIFIED`，该落盘问题已在本次 iOS 16.0.2 真机单独核验：设备 plist 下载后经 `plistlib` 读取确认，SpringBoard 也读取到相同设置。图片生产方法的连续保存和旧图清理同样通过，测试图片、图片目录及安装暂存均已清理。

真实 `/rootfs/var/tmp` 前后顶层条目没有新增或删除，递归检索未发现插件或测试图片残留；七项既有系统目录或现有 ios-mcp 日志元数据有更新，不能称整个目录完全未变。真实 `/rootfs/var/mobile/Library` 下未发现插件图片目录、同名偏好或安装缓存。该结果限于本次核验，完整记录见 [TESTING.md](TESTING.md)。

## 包和组件

- 包：`io.github.suckdrygod.touchdan`，当前开发版本 `0.1.0`。
- SpringBoard 插件：`TouchDan`。
- 设置面板：`TDNPrefs`。
- 控制中心模块：`CCTouchDan`。
- 设备架构：arm64、arm64e；最低目标 iOS 16.0。
- 与上游包 `com.82flex.touchvis` 声明冲突。

构建阶段将根 LICENSE、NOTICE 和 LICENSES 中的许可纳入设置包资源。请不要从分发包中删去这些文件。

## CI 与模拟器

`.github/workflow-templates/build.yml` 是可选的 GitHub Actions 模板，尚未经过该分支的远端 CI 验证。只有复制到 `.github/workflows/build.yml` 后才会启用；它用于构建并上传工作流产物，不创建 GitHub Release。此前继承的自动发布流程已移除。

系统级 SpringBoard 覆盖与普通 UIKit 演示 App 不同。模拟器专用脚本不作为已验证的安装流程；构建不会自动把插件注入模拟器，也不依赖 RevealServer。除上述 iOS 16.0.2 已完成项目外，其余真机场景仍需在可恢复的专用测试环境逐项完成。

## 二进制依赖的复现范围

当前可以按上述目录结构使用继承的 xcframework，但缺少足以确认其源码版本和构建选项的锁定记录。若要重新生成这些框架，应记录各自的源码提交、Xcode/Swift 版本、架构与命令，并重新核对接口。现有框架的文件清单与哈希见 [binary-dependencies.json](binary-dependencies.json)，它只标识本次继承的文件，不证明其源代码版本。
