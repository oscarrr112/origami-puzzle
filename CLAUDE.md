# 项目规则

## 语言

始终使用中文回答。

## 编译检查

修改任何 `.gd` 文件后，必须立即运行以下命令检查编译：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit --path /Volumes/Mac/GameDev/origami-puzzle 2>&1
```

- 在代码审查之前执行
- 在告知用户测试之前执行
- 编译失败必须先修复再继续
- 子代理（subagent）也必须遵守此规则
