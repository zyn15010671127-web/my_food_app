from datetime import date, datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, select

from app.models import ActivityLevel, Goal, MealRecord, MealType, NutritionTarget, Sex, UserProfile
from app.schemas import DailyProgress, DailySummary, MealSummary, NutritionTotals, TargetRead

ACTIVITY = {ActivityLevel.sedentary: 1.2, ActivityLevel.light: 1.375,
            ActivityLevel.moderate: 1.55, ActivityLevel.high: 1.725, ActivityLevel.very_high: 1.9}
# 固定值是课程原型的可解释业务参数，不能替代个体营养评估。
RULES = {Goal.lose_fat: (0.85, 2.0), Goal.gain_muscle: (1.10, 1.8),
         Goal.maintain: (1.0, 1.2), Goal.shape: (1.0, 1.6)}
MEAL_SHARES = {MealType.breakfast: 0.30, MealType.lunch: 0.35,
               MealType.dinner: 0.30, MealType.snack: 0.05}
NUTRIENTS = ("calories_kcal", "protein_g", "carbs_g", "fat_g")


def today():
    return datetime.now(timezone(timedelta(hours=8))).date()


def calculate_target(profile):
    bmr = 10 * profile.weight_kg + 6.25 * profile.height_cm - 5 * profile.age
    bmr += 5 if profile.sex == Sex.male else -161
    factor, protein_per_kg = RULES[profile.goal]
    tdee = bmr * ACTIVITY[profile.activity_level]
    calories = max(bmr, tdee * factor)
    protein = profile.weight_kg * protein_per_kg
    fat = calories * 0.25 / 9
    carbs = (calories - protein * 4 - fat * 9) / 4
    if bmr <= 0 or carbs <= 0:
        raise HTTPException(422, "档案数据无法生成合理的原型营养目标，请核对年龄、身高和体重")
    return {"bmr_kcal": round(bmr, 2), "tdee_kcal": round(tdee, 2),
            "calories_kcal": round(calories, 2), "protein_g": round(protein, 2),
            "carbs_g": round(carbs, 2), "fat_g": round(fat, 2), "goal": profile.goal}


def ensure_target(session: Session, user_id: int, day: date, recalculate=False):
    target = session.exec(select(NutritionTarget).where(
        NutritionTarget.user_id == user_id, NutritionTarget.record_date == day)).first()
    if target is not None and not recalculate:
        return target
    if recalculate and day < today():
        raise HTTPException(409, "历史目标已保存，不能重新计算；请使用今天或未来日期")
    profile = session.get(UserProfile, user_id)
    if profile is None:
        raise HTTPException(404, "请先建立个人档案")
    values = calculate_target(profile)
    snapshot = profile.model_dump(mode="json", exclude={"updated_at"})
    if target is None:
        target = NutritionTarget(user_id=user_id, record_date=day, **values, profile_snapshot=snapshot)
    else:
        target.sqlmodel_update({**values, "profile_snapshot": snapshot})
    session.add(target)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        target = session.exec(select(NutritionTarget).where(
            NutritionTarget.user_id == user_id, NutritionTarget.record_date == day)).first()
        if target is None:
            raise HTTPException(409, "目标保存冲突，请重试") from None
    session.refresh(target)
    return target


def daily_summary(session: Session, user_id: int, day: date):
    rows = session.exec(select(MealRecord.meal_type, func.count(MealRecord.id),
        func.sum(MealRecord.calories_kcal), func.sum(MealRecord.protein_g),
        func.sum(MealRecord.carbs_g), func.sum(MealRecord.fat_g)).where(
            MealRecord.user_id == user_id, MealRecord.record_date == day
        ).group_by(MealRecord.meal_type)).all()
    summaries = {kind: MealSummary(meal_type=kind) for kind in MealType}
    for kind, count, calories, protein, carbs, fat in rows:
        summaries[kind] = MealSummary(meal_type=kind, record_count=count,
            calories_kcal=round(calories, 2), protein_g=round(protein, 2),
            carbs_g=round(carbs, 2), fat_g=round(fat, 2))
    meals = list(summaries.values())
    total = NutritionTotals(**{name: round(sum(getattr(m, name) for m in meals), 2) for name in NUTRIENTS})
    return DailySummary(record_date=day, record_count=sum(m.record_count for m in meals), total=total, meals=meals)


def daily_progress(session: Session, user_id: int, day: date):
    target = ensure_target(session, user_id, day)
    consumed = daily_summary(session, user_id, day).total
    remaining, exceeded, percent = {}, {}, {}
    for name in NUTRIENTS:
        difference = round(getattr(target, name) - getattr(consumed, name), 2)
        remaining[name] = max(difference, 0)
        exceeded[name] = max(-difference, 0)
        percent[name] = round(getattr(consumed, name) / getattr(target, name) * 100, 2)
    return DailyProgress(record_date=day, target=TargetRead.model_validate(target),
        consumed=consumed, remaining=NutritionTotals(**remaining),
        exceeded=NutritionTotals(**exceeded), completion_percent=NutritionTotals(**percent))


def trend(session, user_id, start, end):
    if end < start or (end - start).days > 89:
        raise HTTPException(422, "日期范围应为 1 至 90 天，结束日期不能早于开始日期")
    rows = session.exec(select(MealRecord.record_date, func.count(MealRecord.id),
        func.sum(MealRecord.calories_kcal), func.sum(MealRecord.protein_g),
        func.sum(MealRecord.carbs_g), func.sum(MealRecord.fat_g)).where(
            MealRecord.user_id == user_id, MealRecord.record_date >= start,
            MealRecord.record_date <= end).group_by(MealRecord.record_date)).all()
    mapping = {r[0]: r for r in rows}
    result = []
    for offset in range((end - start).days + 1):
        day = start + timedelta(days=offset)
        row = mapping.get(day)
        result.append({"record_date": day, "record_count": row[1] if row else 0,
            "total": NutritionTotals(**dict(zip(NUTRIENTS, [round(v, 2) for v in row[2:]]))) if row else NutritionTotals()})
    return result
