import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from app.config import Settings
from app.main import create_app

app = create_app(Settings(data_dir=ROOT / '.build-docs', jwt_secret='documentation-only-' * 4, seed_demo=False))
schema = app.openapi()
docs = ROOT / 'docs'
docs.mkdir(exist_ok=True)
(docs / 'openapi.json').write_text(json.dumps(schema, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

intro = '''# 接口说明

## 基本约定

- 本机默认地址为 `http://127.0.0.1:8010`，交互测试页面为 `/docs`。
- 登录接口使用JSON用户名与密码。个人接口请求头为 `Authorization: Bearer <access_token>`。
- 食物库每100克营养；菜谱每份营养；饮食记录按实际食用克数计算。
- 热量单位为千卡，其余三大营养素单位为克；身高厘米、体重千克。
- 日期为 `YYYY-MM-DD`。记录与统计使用显式日期；目标、推荐省略日期时按UTC+8当天。
- 分页采用 `offset`、`limit`，列表默认20条、最大100条。汇总不受列表分页影响。
- `PUT`为完整替换，请提交该请求模型所需全部字段。
- 错误响应含 `detail` 和 `request_id`；参数错误为422，不回显密码输入。
- `204`成功响应没有正文。Token过期或无效返回401，角色不足403，资源不属于自己统一404。

## 身份与角色

注册、登录、健康检查及公开食物/菜谱查询无须登录。个人档案、记录、统计、推荐、图片、问答、账号导出与删除均需登录。食物/菜谱的写入、停用、导入和管理概览需要管理员。

演示账号为 `demo_user / DemoPass123!`，演示管理员为 `admin / AdminDemo123!`。它们仅用于开发模式。

## 常用请求示例

登录：

```json
{"username":"demo_user","password":"DemoPass123!"}
```

保存档案：

```json
{"sex":"female","age":21,"height_cm":165,"weight_kg":55,"goal":"maintain","activity_level":"moderate","body_fat_percent":null}
```

新增或完整修改饮食记录，`food_id`须替换为真实食物编号：

```json
{"food_id":40,"grams":150,"meal_type":"lunch","record_date":"2026-10-23"}
```

普通营养问题：

```json
{"message":"蛋白质是什么","allow_external_processing":false}
```

图片流程：先通过multipart上传得到`image_id`，再提交识别请求：

```json
{"image_id":"上传返回的32位编号","allow_external_processing":false}
```

识别接口返回`manual_required`时可以继续手动选择食物，确认接口路径中的编号是`recognition_id`：

```json
{"meal_type":"lunch","record_date":"2026-10-23","items":[{"food_id":40,"grams":150}]}
```

确认成功后重复提交返回409，防止重复记餐。候选食物名称与份量不自动当作已确认事实。

目标进度字段：`target`为保存的当日目标，`consumed`为已摄入量，`remaining`与`exceeded`分别给出非负的剩余及超出量，`completion_percent`可超过100。已有目标不会随档案自动变化，今天或未来目标通过重算接口主动更新；历史日期不能重算。

菜谱食材的`grams`均对应一份；记录菜谱时用`servings`乘份数。推荐默认3套，筛选后不足3套会如实说明。问答返回`mode=local_knowledge`或`external_model`，识别返回`manual_fallback`或`external_vision`，不得把本地降级模式描述为真实视觉识别成功。

## 接口清单

下表从当前应用的OpenAPI直接生成，完整请求字段、枚举、返回模型及校验限制见同目录`openapi.json`，可导入支持OpenAPI的接口工具。

| 方法 | 路径 | 功能 |
| --- | --- | --- |
'''
rows = []
operations = []
for path, item in schema['paths'].items():
    for method, operation in item.items():
        if method not in {'get','post','put','delete','patch'}:
            continue
        operations.append((method, path, operation))
        rows.append(f"| {method.upper()} | `{path}` | {operation.get('summary','')} |")
footer = '''

## 状态码

| 状态码 | 含义 |
| --- | --- |
| 200 | 查询、登录或更新成功 |
| 201 | 注册、新增记录、上传或识别任务创建成功 |
| 204 | 删除或退出登录成功，无正文 |
| 401 | 未登录、凭证失效或密码错误 |
| 403 | 当前用户没有管理员权限 |
| 404 | 资源不存在、已停用或不属于当前账号 |
| 409 | 用户名/名称重复、重复确认或历史目标禁止重算 |
| 413 | 请求或文件超过大小限制 |
| 422 | 字段校验、图片解析、导入数据或日期范围不合法 |
| 429 | 请求频率超限，等待Retry-After指定秒数 |
| 503 | 健康检查发现数据库不可用 |

## 管理端导入

食物CSV文件须为UTF-8，必要列为`name,calories_kcal,protein_g,carbs_g,fat_g`；可选`aliases`使用竖线分隔，另可提供`gi,source`。模板见`data/foods_import_template.csv`。每次最多1MB、5000行，整批校验后原子提交。同名食物更新，新名称新增；历史饮食记录不变，相关菜谱营养同步更新。

菜谱批量导入接收JSON数组，每项符合`RecipeSave`，食材使用已有`food_id`与`grams`，每次1至500套。演示文件`data/demo_recipes.json`用名称表达食材，供初始化脚本映射，不应直接当作批量API的编号版请求。

## 隐私接口

导出接口只导出当前账号结构化数据，图片二进制单独通过私有图片接口读取。删除账号需要JSON密码确认，会删除档案、目标、饮食、识别、会话及图片。该操作不会删除公共食物库与菜谱库。
'''
(docs / '接口说明.md').write_text(intro + '\n'.join(rows) + footer, encoding='utf-8')

def sample(spec, depth=0):
    if depth > 8:
        return None
    if '$ref' in spec:
        return sample(schema['components']['schemas'][spec['$ref'].split('/')[-1]], depth+1)
    if 'default' in spec and spec['default'] is not None:
        return spec['default']
    if 'enum' in spec:
        return spec['enum'][0]
    if 'anyOf' in spec:
        return sample(next(x for x in spec['anyOf'] if x.get('type') != 'null'), depth+1)
    kind = spec.get('type')
    if kind == 'object':
        return {key: sample(value,depth+1) for key,value in spec.get('properties',{}).items() if key in spec.get('required',[])}
    if kind == 'array':
        return [sample(spec.get('items',{}),depth+1)]
    if kind in ('integer','number'):
        return max(spec.get('minimum',1), spec.get('exclusiveMinimum',0)+1)
    if kind == 'boolean':
        return False
    if spec.get('format') == 'date':
        return '{{record_date}}'
    return 'example'

def item(name, method, path, body=None, query=None, admin=False, capture=None, noauth=False, files=None):
    auth = {'type':'noauth'} if noauth else {'type':'bearer','bearer':[{'key':'token','value':'{{admin_token}}' if admin else '{{token}}','type':'string'}]}
    url = '{{base_url}}' + path
    if query:
        url += '?' + '&'.join(f'{k}={v}' for k,v in query.items())
    request = {'method':method,'header':[], 'url':url, 'auth':auth}
    if files:
        request['body']={'mode':'formdata','formdata':[{'key':'file','type':'file','src':''}]}
    elif body is not None:
        request['header']=[{'key':'Content-Type','value':'application/json'}]
        request['body']={'mode':'raw','raw':json.dumps(body,ensure_ascii=False,indent=2),'options':{'raw':{'language':'json'}}}
    result={'name':name,'request':request}
    if capture:
        result['event']=[{'listen':'test','script':{'type':'text/javascript','exec':capture}}]
    return result

flow = [
item('01 健康检查','GET','/api/health',noauth=True),
item('02 普通用户登录','POST','/api/auth/login',{'username':'demo_user','password':'DemoPass123!'},noauth=True,capture=["if (pm.response.code === 200) pm.environment.set('token', pm.response.json().access_token);"]),
item('03 查看档案','GET','/api/profile/me'),
item('04 查询测试食物并记住编号','GET','/api/foods',query={'q':'测试食物'},noauth=True,capture=["if(pm.response.code===200 && pm.response.json().length) pm.environment.set('food_id', pm.response.json()[0].id);"]),
item('05 新增饮食并记住记录编号','POST','/api/meal-records',{'food_id':'{{food_id}}','grams':150,'meal_type':'lunch','record_date':'{{record_date}}'},capture=["if(pm.response.code===201) pm.environment.set('record_id', pm.response.json().id);"]),
item('06 查询当天记录','GET','/api/meal-records/me',query={'record_date':'{{record_date}}'}),
item('07 每日汇总','GET','/api/nutrition/daily',query={'record_date':'{{record_date}}'}),
item('08 每日目标','GET','/api/nutrition/target',query={'record_date':'{{record_date}}'}),
item('09 目标与摄入对比','GET','/api/nutrition/progress',query={'record_date':'{{record_date}}'}),
item('10 三套候选推荐','GET','/api/recommendations',query={'record_date':'{{record_date}}','meal_type':'lunch'}),
item('11 修改刚创建的记录','PUT','/api/meal-records/{{record_id}}',{'food_id':'{{food_id}}','grams':200,'meal_type':'dinner','record_date':'{{record_date}}'}),
item('12 本地知识库问答','POST','/api/chat/messages',{'message':'蛋白质是什么','allow_external_processing':False}),
item('13 规则编排推荐','POST','/api/agents/dispatch',{'message':'推荐午餐','record_date':'{{record_date}}'}),
item('14 上传图片（先选择本地文件）','POST','/api/uploads/images',files=True,capture=["if(pm.response.code===201) pm.environment.set('image_id',pm.response.json().id);"]),
item('15 创建识别或手动降级任务','POST','/api/recognitions',{'image_id':'{{image_id}}','allow_external_processing':False},capture=["if(pm.response.code===201) pm.environment.set('recognition_id',pm.response.json().id);"]),
item('16 人工确认并保存','POST','/api/recognitions/{{recognition_id}}/confirm',{'meal_type':'lunch','record_date':'{{record_date}}','items':[{'food_id':'{{food_id}}','grams':100}]}),
item('17 个人数据导出','GET','/api/account/export'),
item('18 删除第05步的测试记录','DELETE','/api/meal-records/{{record_id}}'),
item('19 管理员登录','POST','/api/auth/login',{'username':'admin','password':'AdminDemo123!'},noauth=True,capture=["if(pm.response.code===200) pm.environment.set('admin_token',pm.response.json().access_token);"]),
item('20 管理概览','GET','/api/admin/overview',admin=True),
item('21 CSV导入（先选择模板文件）','POST','/api/admin/foods/import',admin=True,files=True),
]
collection={'info':{'name':'智能饮食系统后端演示流程','schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json','description':'完整接口结构见openapi.json；此集合按演示步骤安排。图片和CSV请求需手动选择文件。'},'item':flow}
(docs / '饮食系统.postman_collection.json').write_text(json.dumps(collection,ensure_ascii=False,indent=2),encoding='utf-8')
env={'name':'饮食系统本机演示','values':[{'key':key,'value':value,'enabled':True} for key,value in {'base_url':'http://127.0.0.1:8010','token':'','admin_token':'','record_date':'2026-10-23','food_id':'40','record_id':'1','image_id':'','recognition_id':''}.items()], '_postman_variable_scope':'environment'}
(docs / '本机演示.postman_environment.json').write_text(json.dumps(env,ensure_ascii=False,indent=2),encoding='utf-8')
app.state.engine.dispose()
print(f'Exported {len(operations)} API operations, OpenAPI, interface guide and Postman demo flow.')
