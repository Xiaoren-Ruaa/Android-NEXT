# Linux Addon Build Farm

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Platform](https://img.shields.io/badge/platform-arm64-blue)

面向 ARM64 的构建仓库，当前分成两条产物线：

- Android ARM64 静态工具构建
- Linux ARM64 开发运行时 bundle

这次重构的目标不是改掉 GitHub Actions，而是把原来堆在 workflow 里的构建逻辑拆到可复用脚本和版本清单里，让 CI 继续在 GitHub Actions 上跑，但仓库结构更容易维护。

## 重构后的结构

```text
.
├── .github/workflows/        # CI 编排层，只负责触发和上传产物
├── manifests/                # 版本与产物清单
├── scripts/
│   ├── lib/                  # 通用 shell 函数
│   └── packages/             # 各产物的构建脚本
├── build/                    # 本地和 CI 的临时构建目录（已忽略）
└── dist/                     # 构建输出目录（已忽略）
```

## 当前能力

### 1. 静态工具线

- 继续保留现有 GitHub Actions 产物模式
- 已先把 Bash 构建从 workflow 内联逻辑提取到脚本层
- 后续可以按同一模式继续迁移 BusyBox、Dropbear、Kernel 等 workflow

### 2. 开发运行时 bundle

新增一条独立的 ARM64 runtime bundle 产物线，用于打包：

- Node.js
- npm
- npx
- corepack
- Python
- pip
- uv
- nvm

对应工作流：

- Build ARM64 Dev Runtime Bundle

对应版本清单：

- manifests/runtime-toolchain.env

对应构建脚本：

- scripts/packages/build-runtime-toolchain.sh

## 重要边界

Node.js、Python、uv 这条运行时 bundle 使用的是 linux-arm64 现成发行包，目标是：

- glibc arm64 rootfs
- 容器环境
- chroot 或 proot 用户态环境
- 其他标准 Linux userspace

它不是纯静态 Android /system/bin 替代品。

如果你后面要把 Node.js 或 Python 真正做成“直接跑在原生 Android 用户空间里”的产物，就需要单独开一条 Android/Bionic 交叉编译链，而不是复用这里的 glibc bundle。

## 使用方式

### GitHub Actions

推荐方式仍然是直接在 GitHub Actions 里跑：

1. 进入 Actions
2. 选择目标 workflow
3. 手动触发 workflow_dispatch
4. 从 artifact 下载产物

### Runtime bundle 使用说明

解压 runtime bundle 后：

```bash
source ./toolchain/env.sh
node --version
npm --version
npx --version
python3 --version
uv --version
nvm --version
```

说明：

- npm 和 npx 来自 Node.js 官方发行包
- nvm 既可以通过 source env.sh 后作为 shell function 使用，也提供了命令包装脚本

## 维护约定

- workflow 负责编排，不再承载大段构建逻辑
- 版本优先写入 manifests
- 构建实现优先放到 scripts/packages
- 临时目录统一落到 build
- 最终产物统一落到 dist

## 注意事项

- 本项目仅供学习和实验使用，动手前请先备份
- 部分现有静态工具仍然依赖特定内核能力或系统配置
- 旧 workflow 目前还没有全部迁移到脚本层，这次只先建立统一模式

## License

MIT License © 2026 6ef1c6c

仓库内脚本、配置和文档采用 [MIT License](LICENSE) 授权。
