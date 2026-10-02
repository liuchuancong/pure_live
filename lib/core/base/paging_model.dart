enum PagingMode {
  serverRemote, // 标准服务端分页(page+pageSize)
  serverFixedSize, // 服务端固定页大小，前端自定义分页
  serverAll, // 服务端返回全量，前端分页
  localReactive, // 本地响应式列表，实时分页
}
