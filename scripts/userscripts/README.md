# 用户脚本

安装方式：

1. 安装 Tampermonkey。
2. 优先打开仓库根目录的 `glm-coding-helper.user.js`。
3. 复制全部内容，新建 Tampermonkey 脚本并保存。
4. 启动本地后端：`powershell -ExecutionPolicy Bypass -File scripts\start_backend.ps1 -Mode auto`。

这个目录保留给开发和旧路径兼容。普通用户直接看仓库根目录的脚本文件即可。

默认后端地址为：

```text
http://127.0.0.1:8888
```

脚本默认使用作者内置 GLM Coding Plan 折扣入口；如有需要可自行修改入口参数。

默认不自动关闭无效支付链接/限流弹窗，需要在配置面板里手动开启。

快捷键：

- `Esc`：关闭系统繁忙弹窗或支付弹窗
- `Enter` / `Space`：点击验证码确认按钮
