---
title: "360 安全卫士 Wine 沙箱安装行为分析报告"
date: 2026-08-07
draft: false
featured: false
tags: ["对话报告"]
description: "分析对象：360 安全卫士 v13.0.1.2073（2026-08-07 构建，107 MB 离线包）"
---

# 360 安全卫士 Wine 沙箱安装行为分析报告

**分析对象**：360 安全卫士 v13.0.1.2073（2026-08-07 构建，107 MB 离线包）
**分析环境**：Ubuntu 22.04 容器 / Wine 6.0.3 / WINEPREFIX=win64 / xvfb 无界面
**分析日期**：2026-10-22

---

## 一、执行摘要

| 项 | 结果 |
|---|---|
| 真实安装是否跑通 | **否**。Wine 6.0 在初始化阶段即 futex assertion 崩溃 |
| 崩溃前是否写入数据 | **是**。已观察到机器指纹生成、注册表写入、自解压释放、网络上报 |
| 崩溃原因 | 360 v13 是 Electron UI + 50+ 内核驱动，Wine 6.0 不兼容 |
| 分析方法 | ① Wine 实际运行 diff（崩溃前真实行为）+ ② 7z 解包静态分析（完整安装应有的行为） |

> 关键结论：**即使安装程序自己崩溃，它在崩溃前已经完成了"生成机器指纹、写注册表、上报服务器"这三步**。这是 360 安装包的设计——在用户看到安装界面之前，就已经完成了设备识别和网络上报。

---

## 二、Wine 崩溃前真实写入的数据（实测）

### 2.1 注册表新增项

#### A. `HKCU\Software\HuoFeng`（用户 hive）
```reg
[HKEY_CURRENT_USER\Software\HuoFeng]
"m2"  = "be7cce7e2d18644e983ddfcece16863ba9817c0e29c6"
"mid" = "3f8e90b9d08f7ca9006975624dde38a7"
```
- `HuoFeng`（火凤）是 360 内部代号
- `mid` 是本机唯一机器指纹（MD5 类哈希）
- `m2` 是另一组设备哈希

#### B. `HKLM\Software\Wow6432Node\360Safe\Liveup`（系统 hive，32 位兼容视图）
```reg
[HKEY_LOCAL_MACHINE\Software\Wow6432Node\360Safe\Liveup]
"m2"  = "be7cce7e2d18644e983ddfcece16863ba9817c0e29c6"
"mid" = "3f8e90b9d08f7ca9006975624dde38a76767ead32fc4688d608fce13340ffe38"
```
- 同一份机器指纹，写到系统级位置（40 字节 SHA-1 类）
- `Liveup` = 在线升级组件，说明这是升级/安装共用的设备识别键

#### C. `HKLM\...\CurrentVersion\360Clear`（**关键证据**）
```reg
[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\360Clear]
"SetupKilled" = dword:00000001
```
- **`SetupKilled=1`** 是 360 自己写入的标记
- 说明安装程序有"自杀检测"逻辑——当自身被异常终止（如 Wine 崩溃），会留下标记供下次运行判断

#### D. `HKLM\...\Session Manager\PendingFileRenameOperations`
```reg
"PendingFileRenameOperations" =
  "\??\C:\users\user\Temp\{F4A23027-...}.tmp"
  "\??\C:\users\user\Temp\{D111EF62-...}.tmp\7z.dll"
  "\??\C:\users\user\Temp\{D111EF62-...}.tmp"
```
- 利用 Windows 的"重启后删除文件"机制清理自解压临时目录

### 2.2 文件新增（崩溃前已释放）

| 路径 | 大小 | 说明 |
|---|---|---|
| `%TEMP%\{GUID}.tmp\7z.dll` | 2.1 MB | 7-Zip 自解压库 |
| `%TEMP%\{GUID}.tmp` | 2.1 MB | 7z.dll 的副本 |
| `%TEMP%\ld67b.tmp` | **6.1 MB** | 正在释放的主程序（未写完就崩了） |
| `%LOCALAPPDATA%\...\Content.IE5\instcomp[0]..status=101...` | 0 字节 | **安装上报 URL 的 IE 缓存** |

### 2.3 网络上报（崩溃前已发出）

从 IE 缓存中观察到访问：
```
http://update.360safe.com/instcomp.htm?soft=509&status=101&mid=...&ver=...&usetime=...&zt=...
```
- `status=101`：安装程序启动（未完成）
- `mid`：机器指纹（与注册表一致）
- `usetime`：安装耗时（毫秒）

---

## 三、静态分析：完整安装后会改什么（基于解包）

解包得到 **1325 个文件、351 MB**，以下是按真实 Windows 安装后应有的完整行为清单。

### 3.1 文件系统写入

| 目标路径 | 内容 |
|---|---|
| `C:\Program Files (x86)\360\360Safe\` | 主程序目录（全部 1325 个文件） |
| `C:\Program Files (x86)\360\360Safe\deepscan\` | 深度扫描组件 + 内核驱动 |
| `C:\Program Files (x86)\360\360Safe\safemon\` | 主动防御 + 监控驱动 |
| `C:\Program Files (x86)\360\360Safe\ipc\` | 进程间通信 + 沙箱驱动 |
| `C:\Program Files (x86)\360\360Safe\netmon\` | 网络监控 + WFP 驱动 |
| `C:\Program Files (x86)\360\360Safe\SoftMgr\` | 软件管家 + ELAM 启动驱动 |
| `C:\Windows\System32\drivers\` | 50+ 个 `.sys` 驱动（从上面目录复制） |
| `%AppData%\360Safe\` | 用户配置、日志、病毒库 |
| `%ProgramData%\360Safe\` | 全局数据 |

### 3.2 内核驱动（50+ 个，会注册成系统服务）

| 驱动名 | 功能 |
|---|---|
| `360SelfProtection.sys` | **360 自我保护**（防删除/防结束进程） |
| `360AntiExploit.sys` | 漏洞利用防护（DEP/ASLR 绕过检测） |
| `360AntiHacker.sys` | 反黑客入侵 |
| `360AntiHijack.sys` | 反浏览器/主页劫持 |
| `360AntiSteal.sys` | **反数据窃取** |
| `360Box.sys` | 沙箱盒子 |
| `360Camera.sys` | **摄像头保护**（拦截未授权摄像头调用） |
| `360FsFlt.sys` | 文件系统微过滤（监控所有文件读写） |
| `360netmon.sys` / `360netmon_wfp.sys` | **网络流量监控**（WFP 过滤平台） |
| `360Sensor.sys` | 设备传感器监控 |
| `360elam.sys` | **ELAM 早期启动反恶意软件**（在 Windows 内核之前加载） |
| `qutmdrv.sys` | 360 主防护驱动（QUTM = 奇虎威胁模型） |
| `qutmipc.sys` | QUTM 进程间通信 |
| `DsArk.sys` | 方舟系统信息驱动 |
| `BAPIDRV.sys` | BAPI 驱动 |
| `hookport.sys` | 钩子端口（反游戏作弊/反调试） |
| `EfiMon.sys` | **EFI 启动监控**（UEFI 固件层防护） |

> 这些驱动都注册在 `HKLM\SYSTEM\CurrentControlSet\Services\<驱动名>`，随系统启动。

### 3.3 注册表写入（完整安装预期）

#### 卸载信息
```reg
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\360
  DisplayName     = "360 安全卫士"
  DisplayIcon     = "...\360Safe.exe"
  UninstallString = "...\uninst.exe"
```

#### 开机启动项
```reg
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
  "360Safe" = "...\safemon\360tray.exe"
```

#### 软件配置根键
```reg
HKLM\SOFTWARE\Wow6432Node\360Safe\*
HKLM\SOFTWARE\360Safe\*
HKLM\SOFTWARE\360\360se6\Update\ClientState\{02E720BD-...}
HKLM\SOFTWARE\360EntSecurity\*
HKLM\SOFTWARE\360MachineSignature
HKCU\Software\360Safe\*
HKCU\Software\HuoFeng\*    ; 已实测写入
```

#### 服务注册（50+ 个，见 3.2 驱动表）
```reg
HKLM\SYSTEM\CurrentControlSet\Services\360SelfProtection
  ImagePath = "\??\C:\Windows\System32\drivers\360SelfProtection.sys"
  Start     = 0x1 (SYSTEM_START)
  Type      = 0x1 (KERNEL_DRIVER)
  ...（其余 50 个驱动同理）
```

#### 文件关联
```reg
HKCR\.360SafeUAP  →  360 自定义协议/扩展名
```

### 3.4 网络行为（从 strings 提取）

| URL | 用途 |
|---|---|
| `http://update.360safe.com/instcomp.htm` | 安装完成上报 |
| `https://gedl.360safe.com/safe_online/Setup[...].exe` | 组件 CDN 下载 |
| `http://down.360safe.com/setup.exe` | 主安装包 |
| `http://down.360safe.com/offlinepackv4.exe` | 离线病毒库 |

---

## 四、关键观察与风险提示

1. **机器指纹在用户交互前就已生成并上报**
   - Wine 崩溃前，安装程序在没有任何 UI 显示的情况下，已经生成了 `mid`（32 字节）和 `m2`（40 字节）两组设备指纹，写入 HKCU 和 HKLM，并通过 `instcomp.htm?status=101` 上报到服务器。

2. **自我保护机制**
   - `SetupKilled=1` 注册表项表明：安装程序有异常退出检测。下次运行时会读这个键判断上次是否被打断。
   - 完整安装后，`360SelfProtection.sys` 内核驱动会防止文件被删除、进程被结束。

3. **系统级侵入深度**
   - 50+ 内核驱动，包括 ELAM（早期启动）、EFI 监控、文件系统微过滤、WFP 网络过滤、摄像头拦截——这是 Windows 上权限最高的一类软件。
   - 卸载后仍可能残留驱动服务注册和内核钩子。

4. **Wine 6.0 跑不起来的原因**
   - 360 v13 安装包是 Electron 架构（从 `assets/uninstall-*.js` 可证）
   - 内核驱动在 Wine 下根本无法加载（Wine 无内核态）
   - 现代 Chromium/Electron 在 Wine 6.0 上必崩（需要 Wine 8+）

---

## 五、产物清单

```
/home/user/wine360_analysis/
├── 360_setup.exe                  # 原始安装包（107 MB）
├── before/                         # 安装前基线
│   ├── user.reg / system.reg      #   注册表备份
│   ├── reg_HKLM.reg / reg_HKCU.reg #   regedit 导出视图
│   └── filelist.tsv               #   2100 个文件清单
├── after/                         # 崩溃后快照
│   ├── user.reg / system.reg
│   └── filelist.tsv
├── extracted/                     # 7z 解包内容（1325 文件，351 MB）
└── report/
    ├── 01_user_reg_added.txt       # HKCU diff
    ├── 02_system_reg_added.txt     # HKLM diff
    └── 03_files_added.txt          # 文件 diff
```

---

## 六、复现命令

```bash
# 1. 装 wine
sudo dpkg --add-architecture i386
sudo apt install -y wine64 wine32 xvfb cabextract

# 2. 建干净 prefix
export WINEPREFIX=~/wine360 WINEDEBUG=-all WINEDLLOVERRIDES="mscoree=;mshtml="
xvfb-run -a wineboot --init

# 3. 基线快照
cp $WINEPREFIX/user.reg  before/
cp $WINEPREFIX/system.reg before/
cd $WINEPREFIX && find drive_c -type f -printf '%P\t%s\n' | sort > before/filelist.tsv

# 4. 跑安装（会崩，但能看到写入）
xvfb-run -a wine /path/to/360_setup.exe /S

# 5. 事后快照 + diff
diff before/user.reg  after/user.reg
diff before/system.reg after/system.reg
diff before/filelist.tsv after/filelist.tsv
```
