from __future__ import annotations

import asyncio
from datetime import date, timedelta
from enum import Enum
from typing import Generator, List, Optional

from fastapi import Depends, FastAPI, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import Boolean, Date, ForeignKey, Integer, String, create_engine, event, func, or_, select, text
from sqlalchemy.orm import DeclarativeBase, Session, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class TaskStatus(str, Enum):
    todo = "To-Do"
    in_progress = "In Progress"
    done = "Done"


class TaskPriority(str, Enum):
    high = "High"
    medium = "Medium"
    low = "Low"


class RecurrenceType(str, Enum):
    daily = "daily"
    weekly = "weekly"


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(String, nullable=False)
    due_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False)
    priority: Mapped[str] = mapped_column(String, nullable=False, default="Medium")
    is_recurring: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    recurrence_type: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    position: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    blocked_by_id: Mapped[Optional[int]] = mapped_column(
        Integer,
        ForeignKey("tasks.id", ondelete="SET NULL"),
        nullable=True,
    )


DATABASE_URL = "sqlite:///./tasks.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})


@event.listens_for(engine, "connect")
def _sqlite_enable_foreign_keys(dbapi_connection, connection_record) -> None:
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


def get_session() -> Generator[Session, None, None]:
    session = Session(engine)
    try:
        yield session
    finally:
        session.close()


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(min_length=1, max_length=1000)
    due_date: date
    status: TaskStatus
    priority: TaskPriority = TaskPriority.medium
    is_recurring: bool = False
    recurrence_type: Optional[RecurrenceType] = None
    blocked_by_id: Optional[int] = None


class TaskUpdate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(min_length=1, max_length=1000)
    due_date: date
    status: TaskStatus
    priority: TaskPriority = TaskPriority.medium
    is_recurring: bool = False
    recurrence_type: Optional[RecurrenceType] = None
    blocked_by_id: Optional[int] = None


class TaskOut(BaseModel):
    id: int
    title: str
    description: str
    due_date: date
    status: TaskStatus
    priority: TaskPriority
    is_recurring: bool
    recurrence_type: Optional[RecurrenceType] = None
    position: int
    blocked_by_id: Optional[int] = None


class TaskReorder(BaseModel):
    task_ids: List[int] = Field(min_length=0, description="Every task id exactly once, in display order")


app = FastAPI(title="Task Management API", version="1.0.0")


@app.get("/")
def root() -> dict:
    return {"service": "task-management-api", "docs": "/docs", "tasks": "/tasks"}


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _ensure_priority_column() -> None:
    """SQLite: add priority column to existing DBs created before this field existed."""
    with engine.connect() as conn:
        rows = conn.execute(text("PRAGMA table_info(tasks)")).fetchall()
        col_names = {r[1] for r in rows}
        if "priority" not in col_names:
            conn.execute(
                text("ALTER TABLE tasks ADD COLUMN priority VARCHAR(20) NOT NULL DEFAULT 'Medium'")
            )
            conn.commit()


def _ensure_stretch_columns() -> None:
    """SQLite: recurring + position columns for stretch goals."""
    with engine.connect() as conn:
        rows = conn.execute(text("PRAGMA table_info(tasks)")).fetchall()
        col_names = {r[1] for r in rows}
        if "is_recurring" not in col_names:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN is_recurring BOOLEAN NOT NULL DEFAULT 0"))
            conn.commit()
        if "recurrence_type" not in col_names:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN recurrence_type VARCHAR(20)"))
            conn.commit()
        if "position" not in col_names:
            conn.execute(text("ALTER TABLE tasks ADD COLUMN position INTEGER NOT NULL DEFAULT 0"))
            conn.commit()


def _backfill_positions_if_needed(session: Session) -> None:
    """Assign sequential positions by id when all positions are default (migration)."""
    rows = list(session.execute(select(Task).order_by(Task.id.asc())).scalars().all())
    if not rows:
        return
    if any(r.position != 0 for r in rows):
        return
    for i, row in enumerate(rows):
        row.position = i
    session.commit()


@app.on_event("startup")
def _startup() -> None:
    Base.metadata.create_all(bind=engine)
    _ensure_priority_column()
    _ensure_stretch_columns()
    with Session(engine) as session:
        _backfill_positions_if_needed(session)


def _coerce_priority(value: str) -> TaskPriority:
    try:
        return TaskPriority(value)
    except ValueError:
        return TaskPriority.medium


def _coerce_recurrence(value: Optional[str]) -> Optional[RecurrenceType]:
    if value is None:
        return None
    try:
        return RecurrenceType(value)
    except ValueError:
        return None


def _validate_recurring(is_recurring: bool, recurrence_type: Optional[RecurrenceType]) -> None:
    if is_recurring and recurrence_type is None:
        raise HTTPException(status_code=400, detail="recurrence_type is required when is_recurring is true")


def _next_due_date(base: date, recurrence: RecurrenceType) -> date:
    if recurrence == RecurrenceType.daily:
        return base + timedelta(days=1)
    return base + timedelta(days=7)


def _task_to_out(row: Task) -> TaskOut:
    return TaskOut(
        id=row.id,
        title=row.title,
        description=row.description,
        due_date=row.due_date,
        status=TaskStatus(row.status),
        priority=_coerce_priority(row.priority),
        is_recurring=bool(row.is_recurring),
        recurrence_type=_coerce_recurrence(row.recurrence_type),
        position=row.position,
        blocked_by_id=row.blocked_by_id,
    )


def _ensure_blocked_task_exists(session: Session, blocked_by_id: int) -> None:
    exists_stmt = select(Task.id).where(Task.id == blocked_by_id)
    exists = session.execute(exists_stmt).first()
    if not exists:
        raise HTTPException(status_code=400, detail="blocked_by_id does not exist")


def _next_position(session: Session) -> int:
    mx = session.execute(select(func.coalesce(func.max(Task.position), -1))).scalar()
    return int(mx if mx is not None else -1) + 1


@app.get("/tasks", response_model=List[TaskOut])
def list_tasks(
    q: Optional[str] = Query(
        default=None,
        description="Search in title and description (case-insensitive)",
    ),
    status: Optional[TaskStatus] = Query(default=None, description="Filter by status"),
    priority: Optional[TaskPriority] = Query(default=None, description="Filter by priority"),
    session: Session = Depends(get_session),
) -> List[TaskOut]:
    stmt = select(Task)

    if q:
        like = f"%{q}%"
        stmt = stmt.where(or_(Task.title.ilike(like), Task.description.ilike(like)))

    if status:
        stmt = stmt.where(Task.status == status.value)

    if priority:
        stmt = stmt.where(Task.priority == priority.value)

    stmt = stmt.order_by(Task.position.asc(), Task.id.asc())
    rows = session.execute(stmt).scalars().all()
    return [_task_to_out(row) for row in rows]


@app.patch("/tasks/reorder", status_code=204)
def reorder_tasks(payload: TaskReorder, session: Session = Depends(get_session)) -> Response:
    all_ids = list(session.execute(select(Task.id).order_by(Task.id.asc())).scalars().all())
    expected = set(all_ids)
    got = list(payload.task_ids)
    if len(got) != len(expected):
        raise HTTPException(
            status_code=400,
            detail="task_ids must include every task exactly once",
        )
    if set(got) != expected:
        raise HTTPException(
            status_code=400,
            detail="task_ids must match the set of existing task ids",
        )
    for i, tid in enumerate(got):
        t = session.get(Task, tid)
        if t is None:
            raise HTTPException(status_code=400, detail=f"task id {tid} not found")
        t.position = i
    session.commit()
    return Response(status_code=204)


@app.get("/tasks/{task_id}", response_model=TaskOut)
def get_task(task_id: int, session: Session = Depends(get_session)) -> TaskOut:
    stmt = select(Task).where(Task.id == task_id)
    row = session.execute(stmt).scalars().first()
    if not row:
        raise HTTPException(status_code=404, detail="Task not found")
    return _task_to_out(row)


@app.post("/tasks", response_model=TaskOut, status_code=201)
async def create_task(payload: TaskCreate, session: Session = Depends(get_session)) -> TaskOut:
    # Track A requirement: simulate 2-second delay on creations.
    await asyncio.sleep(2)

    rt = payload.recurrence_type if payload.is_recurring else None
    _validate_recurring(payload.is_recurring, rt)

    if payload.blocked_by_id is not None:
        _ensure_blocked_task_exists(session, payload.blocked_by_id)

    row = Task(
        title=payload.title,
        description=payload.description,
        due_date=payload.due_date,
        status=payload.status.value,
        priority=payload.priority.value,
        is_recurring=payload.is_recurring,
        recurrence_type=rt.value if rt is not None else None,
        position=_next_position(session),
        blocked_by_id=payload.blocked_by_id,
    )
    session.add(row)
    session.commit()
    session.refresh(row)

    return _task_to_out(row)


@app.put("/tasks/{task_id}", response_model=TaskOut)
async def update_task(
    task_id: int, payload: TaskUpdate, session: Session = Depends(get_session)
) -> TaskOut:
    row = session.execute(select(Task).where(Task.id == task_id)).scalars().first()
    if not row:
        raise HTTPException(status_code=404, detail="Task not found")

    old_status = row.status

    # Track A requirement: simulate 2-second delay on updates.
    await asyncio.sleep(2)

    rt = payload.recurrence_type if payload.is_recurring else None
    _validate_recurring(payload.is_recurring, rt)

    if payload.blocked_by_id is not None:
        if payload.blocked_by_id == task_id:
            raise HTTPException(status_code=400, detail="Task cannot block itself")
        _ensure_blocked_task_exists(session, payload.blocked_by_id)

    row.title = payload.title
    row.description = payload.description
    row.due_date = payload.due_date
    row.status = payload.status.value
    row.priority = payload.priority.value
    row.is_recurring = payload.is_recurring
    row.recurrence_type = rt.value if rt is not None else None
    row.blocked_by_id = payload.blocked_by_id

    session.commit()
    session.refresh(row)

    should_spawn_recurring = (
        old_status != TaskStatus.done.value
        and payload.status == TaskStatus.done
        and payload.is_recurring
        and rt is not None
    )

    if should_spawn_recurring:
        new_due = _next_due_date(payload.due_date, rt)
        new_task = Task(
            title=row.title,
            description=row.description,
            due_date=new_due,
            status=TaskStatus.todo.value,
            priority=row.priority,
            is_recurring=True,
            recurrence_type=row.recurrence_type,
            position=_next_position(session),
            blocked_by_id=row.blocked_by_id,
        )
        session.add(new_task)
        session.commit()

    return _task_to_out(row)


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: int, session: Session = Depends(get_session)) -> Response:
    row = session.execute(select(Task).where(Task.id == task_id)).scalars().first()
    if not row:
        raise HTTPException(status_code=404, detail="Task not found")
    session.delete(row)
    session.commit()
    return Response(status_code=204)
