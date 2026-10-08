# Download(下载)

> 统一下载:目标 = ContentRef + MediaTicket;Ticket 过期重新 resolve,任务不失败。

## 结构

```text
DownloadTask / DownloadQueue / DownloadPolicy(并发/网络类型/存储位置)
/ DownloadStorage(files 包管理落盘)
```

## 场景

- 点播视频下载(选集)、音乐下载、弹幕/字幕随包。
- 下载项 = ContentRef → 下载完成后注册为 `local://...` 内容(可进录像/本地播放域)。

## 规则

- 后台下载需 `background` 权限;断点续传;失败分类(网络/磁盘满/票据失效)与重试策略。
- 下载与录制共享存储配额管理(files 包)。
