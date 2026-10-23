# my_food_app

A new Flutter project.

## 后端服务

后端源码位于 [`backend/`](backend/)，使用 Python、FastAPI 和 SQLite，包含营养目标、饮食记录、统计、推荐、图片识别适配和营养问答接口。

在 Windows 下进入 `backend` 后双击 `run.bat`，或执行：

```powershell
cd backend
powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1
```

首次启动需要联网安装锁定依赖。启动后打开 [接口文档](http://127.0.0.1:8010/docs)。演示账号为 `demo_user / DemoPass123!`；这些账号仅用于本地开发。

完整运行说明、接口说明、配置边界与测试报告见 [`backend/README.md`](backend/README.md)。Flutter 当前仍保留原有前端代码，前后端联调需按后端文档配置接口地址。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
