# 智能饮食搭配推荐系统后端

## GitHub源码版说明

本目录为 `my_food_app` 仓库的后端，Flutter前端保留在仓库根目录。GitHub源码版不包含虚拟环境、本地密钥、运行数据库、图片或`wheelhouse`离线安装包。首次运行`run.bat`会联网安装`requirements-lock.txt`中的依赖；需要完全离线安装时使用单独提供的ZIP提交包。

本项目是可运行、可测试的课程后端提交版，采用 Python、FastAPI、SQLModel 和 JWT。默认使用 SQLite，解压后可直接初始化演示账号、120 条演示食物和 24 道演示菜谱；另外提供 PostgreSQL 配置、数据库迁移和 Docker Compose 文件。

当前提供45个API操作，49项自动测试全部通过；接口文档、Postman演示集合、测试报告和Windows Python3.14离线依赖均包含在包中。

本目录交付后端与接口资料，Flutter客户端源码位于上一级仓库目录。

## 快速启动

当前验证环境为 Windows 64 位、Python 3.14.8。将整个 ZIP 解压到一个可写目录，双击 `run.bat`。首次启动会创建虚拟环境、从 `wheelhouse` 离线安装依赖并初始化演示数据。

服务启动后访问：

- 接口测试页面：[http://127.0.0.1:8010/docs](http://127.0.0.1:8010/docs)
- 服务健康检查：[http://127.0.0.1:8010/api/health](http://127.0.0.1:8010/api/health)
- 机器可读接口定义：[http://127.0.0.1:8010/openapi.json](http://127.0.0.1:8010/openapi.json)

默认使用 8010 端口，方便与你原来运行在 8000 端口的练习项目共存。接口文档的 JS 与 CSS 由本机提供，无需连接 CDN。

也可以在 PowerShell 中启动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1
```

更换端口或开启开发热重载：

```powershell
.\run.ps1 -Port 8011 -Reload
```

依赖已安装后，可使用 `run.bat -SkipInstall`。停止服务按 `Ctrl+C`。

`wheelhouse` 里的二进制依赖适配 Windows x64 / CPython 3.14。其他操作系统或 Python 小版本应使用联网安装：新建虚拟环境后执行 `python -m pip install -r requirements-lock.txt`；不要把原虚拟环境直接复制到其他电脑。Docker 采用 Linux 镜像，会自行安装对应依赖。

## 演示账号

| 用途 | 用户名 | 密码 |
| --- | --- | --- |
| 普通用户 | `demo_user` | `DemoPass123!` |
| 管理员 | `admin` | `AdminDemo123!` |

演示账号仅由开发模式的 `SEED_DEMO_DATA=true` 初始化。正式部署必须关闭演示初始化并创建自己的管理员。

## 五分钟演示顺序

1. 在 `/docs` 调用 `POST /api/auth/login`，使用普通演示账号登录。
2. 复制返回的 `access_token`，点击右上角 **Authorize**，只粘贴 Token 本体。
3. 调用 `GET /api/profile/me`、`GET /api/nutrition/target` 查看档案与目标。
4. 调用 `GET /api/foods?q=测试食物`，记下食物编号。
5. 调用 `POST /api/meal-records`，提交该编号、150 克、午餐和一个日期。
6. 查询该日期的 `/api/nutrition/daily`、`/api/nutrition/progress`，验证热量 150、蛋白质 7.5、碳水 22.5、脂肪 3 的增量。
7. 调用 `/api/recommendations`，查看 3 套带食材克数、参考做法和营养信息的推荐。
8. 调用 `/api/chat/messages`，提交 `{"message":"蛋白质是什么"}`，查看知识库回答与来源。
9. 上传一张图片，调用 `/api/recognitions`。没有外部密钥时会明确提示手动录入；通过确认接口选择食物及克数，也能完成拍照记录流程。
10. 使用管理员账号重新登录和授权，演示食物、菜谱维护及 CSV 导入。管理接口不允许普通用户写入。

完整请求示例见 `docs/接口说明.md`，也可导入 `docs/饮食系统.postman_collection.json` 与环境文件。

## 已实现功能

- 注册、Argon2 密码哈希、JWT 登录、当前用户查询、所有设备退出登录、管理员权限。
- 个人档案、BMI、按日期保存营养目标快照、当日或未来目标重新计算。
- 食物搜索、管理、停用、CSV 批量导入；菜谱食材、做法、每份营养与 JSON 批量导入。
- 手动饮食记录、修改、删除、按日期分页查询，按账号隔离；历史营养快照保持稳定。
- 每日餐次汇总、目标与摄入对比、剩余及超出量、7 日概览和最多 90 日趋势。
- 基于目标和剩余配额的规则推荐，默认 3 套；可排除指定食材，可把菜谱按份数记录。
- 私有图片上传、格式与大小校验、移除 EXIF、百度标准菜品识别与可配置视觉模型、失败降级和用户确认保存。
- 本地营养知识库问答、可选外部模型、会话历史与删除、明确的执行模式字段。
- 编排、识别、规划、顾问四类模块；编排采用可解释规则路由。
- 个人数据导出、验证密码后删除账号及关联数据、基础限流、CORS 白名单、请求编号。

## 百度菜品识别配置

1. 在百度智能云开通图像识别服务，创建具有菜品识别权限的应用，取得 API Key 与 Secret Key。
2. 在 `backend/.env` 中填写以下配置。`.env` 已在 `.gitignore` 中，不要将真实密钥写入 `.env.example`、源码或 Git 提交：

```dotenv
ENABLE_BAIDU_DISH=true
BAIDU_API_KEY=你的APIKey
BAIDU_SECRET_KEY=你的SecretKey
```

3. 重启后端，在前端识别页打开“允许使用外部视觉服务”后选择图片。OAuth access token 由后端获取并缓存，前端不会接触百度密钥。
4. 百度标准菜品识别用于单菜品图片；接口 Top-N 是同一菜品的候选，本系统仅取 Top-1 交给用户核对，不将其当作多道菜。营养值仍按本地食物库和用户确认的克数计算，不使用识别结果直接估算份量。
5. 未配置密钥、未同意外传或百度调用失败时，均降级为手动核对，不伪造识别结果。当前补充测试使用模拟百度响应，真实识别准确率需要配置有效密钥后另行验收。

## 数据与算法边界

食物数据和做法为课程演示近似值，`source` 字段明确标记。虚构的“测试食物”仅用于验算。当前是 120 条食物（含 1 条仅用于接口验算的“测试食物”）、24 道菜谱，尚未完成计划书设想的 500 条权威食物与 200 套菜谱数据建设；可通过导入接口继续补充，不能把演示规模写成已经完成大规模数据验收。

营养目标使用计划书中的 Mifflin–St Jeor 公式及固定活动系数；目标调整与蛋白质参数见 `docs/设计与实现说明.md`。结果用于成人一般营养估算，不能替代疾病、孕哺期或其他特殊情况的专业评估；“不低于估算静息消耗”只是项目业务规则，不代表医学安全认证。

首次查询某日目标时保存当时档案的快照。修改档案不会自动覆盖已有目标；需要通过重算接口调整今天或未来日期。历史日期首次补建目标也只能使用当前档案估算，系统没有凭空恢复过去档案的能力。

无外部密钥时，图片识别不会伪造识别结果；问答明确返回 `local_knowledge`。外部视觉模型不估算份量，也不保证返回位置框；由用户确认食物及克数。外部接口已通过模拟响应测试，未使用真实付费密钥完成在线识别准确率验收。

## 依赖与测试

- `requirements.txt`：直接运行依赖。
- `requirements-dev.txt`：开发与测试入口。
- `requirements-lock.txt`：本次验证的完整依赖版本。
- `wheelhouse/`：Windows Python 3.14 离线依赖。

```powershell
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe scripts\load_test.py
```

自动测试使用独立临时数据库，不修改运行数据库。测试结论见 `docs/测试报告.md`，原始结果为 `test-results.xml` 和 `load-test-results.json`。

## PostgreSQL 与部署

本地 SQLite 演示已经实测。PostgreSQL 连接配置、驱动、迁移脚本及生成的 PostgreSQL DDL 已提供；当前机器没有可用的 PostgreSQL/Docker 服务，因此未声称完成真实 PostgreSQL 或云端部署验证。操作步骤见 `docs/部署说明.md`。

## 目录

```text
app/                  配置、数据模型、接口与业务服务
data/                 演示食物、菜谱、知识库、导入模板
docs/                 接口说明、设计说明、部署说明、测试结果
migrations/           Alembic 初始迁移
scripts/              数据库初始化、管理员创建、并发检查
tests/                自动化接口及回归测试
wheelhouse/           当前 Windows 环境的离线依赖
main.py               应用入口
run.bat / run.ps1     Windows 启动入口
run.sh                Linux/macOS 联网安装与启动入口
Dockerfile            容器构建配置
compose.yaml          PostgreSQL 与 API 的组合部署配置
```
