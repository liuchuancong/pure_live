# 坚果云 WebDAV 注册、登录、图文绑定完整教程

## 一、前言（必看）

坚果云是目前国内**最稳定、支持 WebDAV 免费同步**的云盘。

免费用户权益：

- 永久存储空间：**3GB**
- 每月上传流量：**1GB**（次月刷新）

WebDAV 用途：给各类播放器、笔记软件、APP、配置文件做**云同步、云备份**。

**WebDAV 三项核心参数（全程只用这三个）**

|参数名称|填写内容|
|---|---|
|WebDAV 地址|`https://dav.jianguoyun.com/dav/`|
|用户名|你的坚果云**注册邮箱**（重要！不是手机号）|
|WebDAV 密码|第三方应用密码（**不是登录密码**）|

---

## 二、坚果云账号注册教程（新手从零开始）

### 1. 进入官网

打开浏览器访问：[https://www.jianguoyun.com](https://www.jianguoyun.com)

![坚果云官网首页]https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/webdav/00_home.png)

### 2. 点击注册

点击右上角 **注册**，推荐使用 **邮箱注册**（WebDAV 必须依赖邮箱账号）

![注册界面]https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/webdav/02_register.png)

### 3. 填写信息

- 邮箱：常用邮箱（QQ/网易/谷歌均可）
- 设置登录密码
- 绑定手机号接收验证码

注册完成后，**去邮箱点击验证链接激活账号**。

---

## 三、网页端登录教程

WebDAV 密码**只能网页端生成**，必须网页登录。

![网页登录界面]https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/webdav/03_login.png)

输入：注册邮箱 + 你的登录密码 → 登录。

---

## 四、【关键步骤】生成 WebDAV 第三方应用密码

**重点：WebDAV 不支持账号登录密码，必须单独创建！**

### 1. 进入账户信息

网页右上角 **头像** → 点击 **账户信息**

![头像下拉菜单]https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/webdav/01_avatar_menu.png)

### 2. 打开安全选项

左侧菜单栏找到：**安全选项**

![安全设置页面]https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/webdav/04_security.png)

### 3. 进入第三方应用管理

下拉找到：**第三方应用与设备管理**

### 4. 添加应用密码

点击 **添加应用密码**

![添加应用弹窗]https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/webdav/05_add_app.png)

- 应用名称：自定义（例如：PureLive 同步、手机备份）
- 权限：默认 **读写**

### 5. 获取 WebDAV 密码

点击生成后，会出现一串 **16 位随机密码**

✅ **立刻复制保存！只显示一次！丢了只能重新生成！**

![生成密码界面]https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/webdav/06_get_pwd.png)

---

## 五、任意软件 WebDAV 通用绑定教程

所有 APP/播放器/笔记软件 统一填写规则：

- 服务器地址：`https://dav.jianguoyun.com/dav/`
- 账号/用户名：**你的坚果云注册邮箱**
- 密码：**刚刚生成的第三方应用密码**

可选（推荐）：加子文件夹分类

示例：专门给播放器用
`https://dav.jianguoyun.com/dav/purelive/`

填写后云端自动创建文件夹，文件不乱。

---

## 六、常见报错与解决

### 1. 提示账号密码错误
- 不要填手机号！必须填 **注册邮箱**
- 不要填登录密码！必须填 **应用密码**

### 2. 浏览器打开 WebDAV 地址提示「网页解析失败」
**✅ 正常现象，不是故障！无需修复**

坚果云 WebDAV 地址 `https://dav.jianguoyun.com/dav/` 是**协议接口地址**，仅支持播放器、笔记软件等第三方工具调用，**不支持浏览器直接访问、网页预览**。

浏览器打开报错、解析失败、空白页，都是服务器的正常拦截机制，**完全不影响软件绑定、同步、备份功能**。

只需正常将该地址填入软件 WebDAV 设置中，搭配正确账号密码即可正常使用。
- 检查网址末尾 `/` 是否存在
- 关闭系统代理、翻墙工具

### 3. 无法上传/同步失败
1. 免费用户每月 **1GB 上传流量** 用完需等次月刷新，下载无限制；
2. 检查网络代理、全局翻墙工具，WebDAV 同步需使用原生网络，代理会导致连接超时、同步中断；
3. 确认生成的应用密码权限为「读写」，仅只读权限无法上传备份文件。

### 4. 连接超时、频繁断开
1. 更换公共DNS（114.114.114.114 / 223.5.5.5），修复域名解析异常问题；
2. 关闭浏览器/系统隐私拦截、广告插件，避免拦截WebDAV协议请求；
3. 核对地址末尾必须带 `/`，缺失斜杠会直接连接失败。

### 5. 想要关闭授权/重置密码
回到坚果云网页端「第三方应用管理」，删除对应自定义应用名称，该WebDAV授权会**立刻失效**。后续使用需重新生成应用密码绑定。

---

## 七、快速总结（懒人复制版）

WebDAV 地址：`https://dav.jianguoyun.com/dav/`
账号：坚果云注册邮箱
密码：网页端生成的第三方应用密码
