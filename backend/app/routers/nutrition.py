from datetime import date, timedelta

from fastapi import APIRouter, Query

from app.deps import SessionDep, UserDep
from app.models import MealType
from app.schemas import DailyProgress, DailySummary, RecommendResult, TargetRead
from app.services.nutrition import daily_progress, daily_summary, ensure_target, today, trend
from app.services.recommendation import recommend

router = APIRouter(tags=["营养统计"])


@router.get("/api/nutrition/daily", response_model=DailySummary, summary="按餐次汇总全天营养")
def get_daily(record_date: date, session: SessionDep, user: UserDep):
    return daily_summary(session, user.id, record_date)


@router.get("/api/nutrition/target", response_model=TargetRead, summary="获取并保存指定日期营养目标快照")
def get_target(session: SessionDep, user: UserDep, record_date: date | None = None):
    return ensure_target(session, user.id, record_date or today())


@router.post("/api/nutrition/target/recalculate", response_model=TargetRead, summary="档案调整后重算今天或未来的目标")
def recalculate_target(session: SessionDep, user: UserDep, record_date: date | None = None):
    return ensure_target(session, user.id, record_date or today(), recalculate=True)


@router.get("/api/nutrition/progress", response_model=DailyProgress, summary="对比目标、摄入、剩余与超出量")
def get_progress(session: SessionDep, user: UserDep, record_date: date | None = None):
    return daily_progress(session, user.id, record_date or today())


@router.get("/api/nutrition/trends", summary="查询最多九十天的每日摄入趋势")
def get_trends(start_date: date, end_date: date, session: SessionDep, user: UserDep):
    return {"start_date": start_date, "end_date": end_date, "days": trend(session, user.id, start_date, end_date)}


@router.get("/api/nutrition/weekly", summary="最近七天摄入概览")
def get_weekly(session: SessionDep, user: UserDep, end_date: date | None = None):
    end = end_date or today()
    days = trend(session, user.id, end - timedelta(days=6), end)
    total = {key: round(sum(getattr(d["total"], key) for d in days), 2)
             for key in ("calories_kcal", "protein_g", "carbs_g", "fat_g")}
    return {"days": days, "total": total, "daily_average": {k: round(v / 7, 2) for k, v in total.items()}}


@router.get("/api/recommendations", response_model=RecommendResult, tags=["饮食推荐"], summary="按目标与剩余营养推荐至少三套候选菜谱")
def recommendations(session: SessionDep, user: UserDep, record_date: date | None = None,
                    meal_type: MealType = MealType.lunch, limit: int = Query(3, ge=3, le=10),
                    exclude_food_ids: list[int] = Query(default=[])):
    return recommend(session, user.id, record_date or today(), meal_type, limit, exclude_food_ids)
