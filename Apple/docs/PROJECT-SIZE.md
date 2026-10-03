# 项目体积与清理 — 2026-10-03

## 当前资源裁剪
按当前转换器的动画、物品及文本来源清单形成依赖闭包，额外保留info/icon元数据及9份进食分层info.lps。原素材由6495文件、1011.32MiB裁剪为4534文件、578.05MiB，减少1961文件、433.28MiB（约42.8%）。未打包图库、Windows主题/字体/语言、未选用动画及其它未依赖资源从当前源码树删除，原件仍可从裁剪前4c32d54d或上游1a06c598获取。

不降低图片质量、不减少当前动作、商品或文本。裁剪后从空输出重新运行三转换器，核对所有生成文件路径及SHA256，避免残留生成资源掩盖依赖遗漏。`verify.sh` 已加入 `audit_resources.py`，对来源清单内哈希、12份额外元数据/分层配置的存在/跟踪状态及未使用跟踪文件做检查；审计只读，不自动删除文件。保留配置中的其它原版字段不等于已迁移该功能。

## 三种空间分别处理
- 当前源码/素材：本批减少约433MiB；GitHub当前源码下载及浅克隆可受益。
- 构建资源/应用：裁剪前已只打包当前动作，有效生成内容不变；另清理30张未引用旧生成帧（3.07MiB），不把这项清理等同于运行时优化；macOS产物和生成资源继续保留。
- Git历史：共享对象包实测约1.41GiB，删除文件不会清除历史对象。本批不重写main/ipet-dev、不强制推送，也不在共享Git目录执行垃圾回收。

只想构建当前版本可使用：
```sh
git clone --depth 1 --single-branch --branch ipet-dev https://github.com/xufilps/iPet.git
```
这会限制克隆历史及分支；需要旧原件时另行fetch，不把浅克隆视为完整历史备份。参数说明见 [Git官方文档](https://git-scm.com/docs/git-clone)。本批未实测网络下载字节，不将文件占用等同网络压缩包大小。

## 本机缓存与恢复
验证完成后清理本工作树 `Apple/.build/`、`Apple/build/Build/Intermediates.noindex/`、`Apple/build/ModuleCache.noindex/`、`Apple/build/SDKExplicitPrecompiledModules/`、`Apple/build/SDKStatCaches.noindex/`、`Apple/build/CompilationCache.noindex/`及`Apple/build/ios/`。它们会在下次构建再生成，不是GitHub已跟踪文件；不删除应用、Resources/PetAssets、测试/实机日志、原库来源或.NET证据生成环境。不使用广泛git clean，也不访问Application Support用户存档。

回滚源码裁剪提交即可恢复目录；部分资源可从裁剪前提交单独恢复。当前JSONv9、版本、养成行为和许可不变；构建缓存无需备份，所有既有验证证据继续保留。

本次本机编译缓存释放845.39MiB，记录在Apple/build/verification/size-cache-cleanup.json；应用与日志保留，删除缓存后严格签名复验通过。4518有效生成文件从空目录重建与基线SHA256相同，30旧帧未引用，Finder元数据不计入内容对照。
