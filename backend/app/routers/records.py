from datetime import date

from fastapi import APIRouter, Query, Response

from app.deps import SessionDep, UserDep
from app.models import MealRecord
from app.schemas import MealRead, MealSave
from app.services.catalog import active_food, make_meal, meal_values, owned_record
from sqlmodel import select

router = APIRouter(prefix="/api/meal-records", tags=["饮食记录"])


@router.post("", response_model=MealRead, status_code=201, summary="记录一种食物")
def create_record(data: MealSave, session: SessionDep, user: UserDep):
    record = make_meal(session, user.id, data)
    session.commit()
    session.refresh(record)
    return record


@router.get("/me", response_model=list[MealRead], summary="按日期查询自己的饮食记录")
def list_records(record_date: date, session: SessionDep, user: UserDep,
                 offset: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=100)):
    return session.exec(select(MealRecord).where(MealRecord.user_id == user.id,
        MealRecord.record_date == record_date).order_by(MealRecord.id.desc()).offset(offset).limit(limit)).all()


@router.put("/{record_id}", response_model=MealRead, summary="完整修改自己的饮食记录并重算营养")
def update_record(record_id: int, data: MealSave, session: SessionDep, user: UserDep):
    record = owned_record(session, user.id, record_id)
    food = active_food(session, data.food_id)
    record.sqlmodel_update({**data.model_dump(), **meal_values(food, data.grams)})
    session.add(record)
    session.commit()
    session.refresh(record)
    return record


@router.delete("/{record_id}", status_code=204, summary="删除自己的饮食记录")
def delete_record(record_id: int, session: SessionDep, user: UserDep) -> Response:
    record = owned_record(session, user.id, record_id)
    session.delete(record)
    session.commit()
    return Response(status_code=204)
