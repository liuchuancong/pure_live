# Recorder(录制)

> 录制 = 统一媒体管线的旁路消费:与播放共用 MediaTicket/刷新逻辑,但输出到文件。

## 1. 管线

```text
ContentRef → resolve → MediaTicket → SegmentScheduler
→ RecordSegment(分段落盘)→ Storage(files 包)→ 媒体库(recording)
```

## 2. 关键规则

- **Ticket 过期刷新,录制不断**:refresh 成功后接续下一段;只有连续刷新失败才终止任务(v1 断流分级恢复的录制版)。
- **分段时钟**:以房间/直播事实时钟切段,避免 PTS 跳变(承接 v1 recording_segment_clock 经验);段与段元数据入库(recorder_repository)。
- 磁盘满/权限丢失 → 分类诊断(storageFull 等,v1 FFmpegFailureClassifier 的知识迁移)→ 可暂停待用户处理,不丢已录内容。
- 录制产出为 `local://recording/...` ContentRef,直接进录像播放域(与本地播放统一)。
- 后台录制需 `background` 权限;移动端受系统限制时明确提示。
