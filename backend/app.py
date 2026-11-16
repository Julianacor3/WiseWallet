
from pathlib import Path
from functools import wraps
from datetime import date, datetime
import math
import os
import json
from sqlalchemy import inspect

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from itsdangerous import (
    URLSafeTimedSerializer,
    BadSignature,
    SignatureExpired
)
from werkzeug.security import (
    generate_password_hash,
    check_password_hash
)
from google import genai
from google.genai import errors as genai_errors


# ==========================================
# CONFIGURACION GENERAL
# ==========================================

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

app = Flask(__name__)

SECRET_KEY = os.getenv("SECRET_KEY")

if not SECRET_KEY or len(SECRET_KEY) < 32:
    raise RuntimeError(
        "SECRET_KEY no configurada o demasiado corta. "
        "Revisa el archivo .env"
    )

app.config["SECRET_KEY"] = SECRET_KEY

# ==========================================
# CONFIGURACION DE GEMINI
# ==========================================

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.8-flash")

gemini_client = (
    genai.Client(api_key=GEMINI_API_KEY)
    if GEMINI_API_KEY
    else None
)

# ==========================================
# CONFIGURACION DE BASE DE DATOS
# ==========================================

DATABASE_URL = os.getenv("DATABASE_URL")

if DATABASE_URL:
    # Conexion PostgreSQL para produccion (Neon)
    if DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace(
            "postgres://",
            "postgresql+psycopg://",
            1
        )
    elif DATABASE_URL.startswith("postgresql://"):
        DATABASE_URL = DATABASE_URL.replace(
            "postgresql://",
            "postgresql+psycopg://",
            1
        )

    app.config["SQLALCHEMY_DATABASE_URI"] = DATABASE_URL

    # Mantener conexiones PostgreSQL saludables
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
        "pool_pre_ping": True,
        "pool_recycle": 300
    }

else:
    # SQLite para desarrollo local
    app.config["SQLALCHEMY_DATABASE_URI"] = (
        f"sqlite:///{BASE_DIR / 'wise_wallet.db'}"
    )

app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

CORS(app)

db = SQLAlchemy(app)

serializer = URLSafeTimedSerializer(app.config["SECRET_KEY"])

# ==========================================
# MODELO DE USUARIO
# ==========================================

class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)

    transactions = db.relationship(
        "Transaction",
        backref="user",
        lazy=True,
        cascade="all, delete-orphan"
    )

    obligations = db.relationship(
        "PaymentObligation",
        backref="user",
        lazy=True,
        cascade="all, delete-orphan"
    )

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email
        }


# ==========================================
# MODELO DE TRANSACCIONES
# ==========================================

class Transaction(db.Model):
    __tablename__ = "transactions"

    id = db.Column(db.Integer, primary_key=True)
    description = db.Column(db.String(150), nullable=False)
    amount = db.Column(db.Float, nullable=False)
    category = db.Column(db.String(80), nullable=False)
    transaction_type = db.Column(db.String(20), nullable=False)

    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id"),
        nullable=False
    )

    def to_dict(self):
        return {
            "id": self.id,
            "description": self.description,
            "amount": self.amount,
            "category": self.category,
            "transaction_type": self.transaction_type,
            "user_id": self.user_id
        }


# ==========================================
# MODELO DE PERFIL FINANCIERO
# ==========================================

class UserProfile(db.Model):
    __tablename__ = "user_profiles"

    id = db.Column(db.Integer, primary_key=True)

    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id"),
        unique=True,
        nullable=False
    )

    occupation = db.Column(db.String(80), nullable=False)
    financial_goal = db.Column(db.String(120), nullable=False)
    monthly_income_range = db.Column(db.String(80), nullable=False)
    monthly_expense_range = db.Column(db.String(80), nullable=False)
    saving_habit = db.Column(db.String(80), nullable=False)
    main_challenge = db.Column(db.String(120), nullable=False)
    savings_goal = db.Column(db.String(100), nullable=True)

    savings_accumulated = db.Column(
    db.Float,
    nullable=False,
    default=0
)

    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "occupation": self.occupation,
            "financial_goal": self.financial_goal,
            "monthly_income_range": self.monthly_income_range,
            "monthly_expense_range": self.monthly_expense_range,
            "saving_habit": self.saving_habit,
            "main_challenge": self.main_challenge,
            "savings_goal": self.savings_goal,
            "savings_accumulated": self.savings_accumulated,
            "completed": True
        }


# ==========================================
# MODELO DE OBLIGACIONES DE PAGO
# ==========================================

class PaymentObligation(db.Model):
    __tablename__ = "payment_obligations"

    id = db.Column(db.Integer, primary_key=True)

    title = db.Column(db.String(120), nullable=False)
    description = db.Column(db.String(250), nullable=True)
    amount = db.Column(db.Float, nullable=False)
    category = db.Column(db.String(80), nullable=False)

    due_date = db.Column(db.Date, nullable=False)

    status = db.Column(
        db.String(20),
        nullable=False,
        default="pendiente"
    )

    created_at = db.Column(
        db.DateTime,
        nullable=False,
        default=datetime.utcnow
    )

    paid_at = db.Column(db.DateTime, nullable=True)

    user_id = db.Column(
        db.Integer,
        db.ForeignKey("users.id"),
        nullable=False
    )

    def to_dict(self):
        today = date.today()

        is_overdue = (
            self.status == "pendiente"
            and self.due_date < today
        )

        return {
            "id": self.id,
            "title": self.title,
            "description": self.description,
            "amount": self.amount,
            "category": self.category,
            "due_date": self.due_date.isoformat(),
            "status": self.status,
            "is_overdue": is_overdue,
            "created_at": (
                self.created_at.isoformat()
                if self.created_at else None
            ),
            "paid_at": (
                self.paid_at.isoformat()
                if self.paid_at else None
            )
        }


# ==========================================
# AUTENTICACION MEDIANTE TOKEN
# ==========================================

def token_required(route_function):

    @wraps(route_function)
    def decorated(*args, **kwargs):

        authorization = request.headers.get("Authorization", "")

        if not authorization.startswith("Bearer "):
            return jsonify({
                "message": "Token de autenticacion requerido"
            }), 401

        token = authorization.split(" ", 1)[1]

        try:
            data = serializer.loads(token, max_age=86400)

            user = db.session.get(User, data["user_id"])

            if user is None:
                return jsonify({
                    "message": "Usuario no encontrado"
                }), 401

        except SignatureExpired:
            return jsonify({
                "message": "El token ha expirado. Inicia sesion nuevamente"
            }), 401

        except (BadSignature, KeyError, TypeError):
            return jsonify({
                "message": "Token invalido"
            }), 401

        request.current_user = user

        return route_function(*args, **kwargs)

    return decorated


# ==========================================
# VALIDAR DATOS DE UNA TRANSACCION
# ==========================================

def validate_transaction_data(data, partial=False):

    if not isinstance(data, dict):
        return None, "El cuerpo de la solicitud debe ser un JSON valido"

    fields = [
        "description",
        "amount",
        "category",
        "transaction_type"
    ]

    if not partial:
        missing = [field for field in fields if field not in data]

        if missing:
            return None, "Faltan campos obligatorios: " + ", ".join(missing)

    result = {}

    if "description" in data:
        description = data["description"]

        if not isinstance(description, str) or not description.strip():
            return None, "La descripcion es obligatoria"

        if len(description.strip()) > 150:
            return None, "La descripcion no puede superar 150 caracteres"

        result["description"] = description.strip()

    if "amount" in data:
        amount = data["amount"]

        if isinstance(amount, bool):
            return None, "El monto debe ser un numero valido"

        try:
            amount = float(amount)
        except (ValueError, TypeError):
            return None, "El monto debe ser un numero valido"

        if not math.isfinite(amount) or amount <= 0:
            return None, "El monto debe ser mayor que cero"

        result["amount"] = amount

    if "category" in data:
        category = data["category"]

        if not isinstance(category, str) or not category.strip():
            return None, "La categoria es obligatoria"

        if len(category.strip()) > 80:
            return None, "La categoria no puede superar 80 caracteres"

        result["category"] = category.strip()

    if "transaction_type" in data:
        transaction_type = data["transaction_type"]

        if not isinstance(transaction_type, str):
            return None, "El tipo debe ser ingreso o gasto"

        transaction_type = transaction_type.strip().lower()

        if transaction_type not in ["ingreso", "gasto"]:
            return None, "El tipo debe ser ingreso o gasto"

        result["transaction_type"] = transaction_type

    return result, None


# ==========================================
# VALIDAR DATOS DE UNA OBLIGACION
# ==========================================

def validate_obligation_data(data, partial=False):

    if not isinstance(data, dict):
        return None, "El cuerpo de la solicitud debe ser un JSON valido"

    required_fields = [
        "title",
        "amount",
        "category",
        "due_date"
    ]

    if not partial:
        missing = [
            field for field in required_fields
            if field not in data
        ]

        if missing:
            return None, (
                "Faltan campos obligatorios: "
                + ", ".join(missing)
            )

    result = {}

    if "title" in data:
        title = data["title"]

        if not isinstance(title, str) or not title.strip():
            return None, "El nombre de la obligacion es obligatorio"

        if len(title.strip()) > 120:
            return None, "El nombre no puede superar 120 caracteres"

        result["title"] = title.strip()

    if "description" in data:
        description = data["description"]

        if description is None:
            description = ""

        if not isinstance(description, str):
            return None, "La descripcion debe ser texto"

        if len(description.strip()) > 250:
            return None, "La descripcion no puede superar 250 caracteres"

        result["description"] = description.strip() or None

    if "amount" in data:
        amount = data["amount"]

        if isinstance(amount, bool):
            return None, "El monto debe ser un numero valido"

        try:
            amount = float(amount)
        except (ValueError, TypeError):
            return None, "El monto debe ser un numero valido"

        if not math.isfinite(amount) or amount <= 0:
            return None, "El monto debe ser mayor que cero"

        result["amount"] = amount

    if "category" in data:
        category = data["category"]

        if not isinstance(category, str) or not category.strip():
            return None, "La categoria es obligatoria"

        if len(category.strip()) > 80:
            return None, "La categoria no puede superar 80 caracteres"

        result["category"] = category.strip()

    if "due_date" in data:
        due_date_value = data["due_date"]

        if not isinstance(due_date_value, str):
            return None, "La fecha debe tener el formato YYYY-MM-DD"

        try:
            result["due_date"] = date.fromisoformat(due_date_value)
        except ValueError:
            return None, "La fecha no es valida. Usa YYYY-MM-DD"

    if "status" in data:
        status = data["status"]

        if not isinstance(status, str):
            return None, "El estado debe ser pendiente o pagada"

        status = status.strip().lower()

        if status not in ["pendiente", "pagada"]:
            return None, "El estado debe ser pendiente o pagada"

        result["status"] = status

    return result, None


# ==========================================
# RUTA PRINCIPAL
# ==========================================

@app.get("/")
def home():

    return jsonify({
        "message": "Wise Wallet API esta funcionando",
        "status": "ok"
    }), 200


# ==========================================
# COMPROBAR CONEXION
# ==========================================

@app.get("/api/health")
def health():

    try:
        db.session.execute(db.text("SELECT 1"))

        return jsonify({
            "message": "Servidor conectado correctamente",
            "database": "SQLite conectada",
            "status": "ok"
        }), 200

    except Exception:
        db.session.rollback()

        return jsonify({
            "message": "Error al conectar con la base de datos",
            "status": "error"
        }), 500


# ==========================================
# REGISTRO DE USUARIOS
# ==========================================

@app.post("/api/auth/register")
def register():

    data = request.get_json(silent=True) or {}

    if not isinstance(data, dict):
        return jsonify({
            "message": "Debes enviar un JSON valido"
        }), 400

    name = data.get("name", "")
    email = data.get("email", "")
    password = data.get("password", "")
    confirm_password = data.get("confirm_password", "")

    if not all([name, email, password, confirm_password]):
        return jsonify({
            "message": "Todos los campos son obligatorios"
        }), 400

    if not all(isinstance(value, str) for value in [
        name, email, password, confirm_password
    ]):
        return jsonify({
            "message": "Los datos enviados no son validos"
        }), 400

    name = name.strip()
    email = email.strip().lower()

    if not name or not email:
        return jsonify({
            "message": "El nombre y el correo son obligatorios"
        }), 400

    if "@" not in email:
        return jsonify({
            "message": "El correo electronico no es valido"
        }), 400

    if len(password) < 6:
        return jsonify({
            "message": "La contrasena debe tener al menos 6 caracteres"
        }), 400

    if password != confirm_password:
        return jsonify({
            "message": "Las contrasenas no coinciden"
        }), 400

    existing_user = User.query.filter_by(email=email).first()

    if existing_user:
        return jsonify({
            "message": "Este correo electronico ya esta registrado"
        }), 409

    new_user = User(
        name=name,
        email=email,
        password=generate_password_hash(password)
    )

    db.session.add(new_user)
    db.session.commit()

    token = serializer.dumps({
        "user_id": new_user.id
    })

    return jsonify({
        "message": "Usuario registrado correctamente",
        "token": token,
        "user": new_user.to_dict()
    }), 201


# ==========================================
# INICIO DE SESION
# ==========================================

@app.post("/api/auth/login")
def login():

    data = request.get_json(silent=True) or {}

    if not isinstance(data, dict):
        return jsonify({
            "message": "Debes enviar un JSON valido"
        }), 400

    email = data.get("email", "")
    password = data.get("password", "")

    if not isinstance(email, str) or not isinstance(password, str):
        return jsonify({
            "message": "Las credenciales no son validas"
        }), 400

    email = email.strip().lower()

    if not email or not password:
        return jsonify({
            "message": "El correo y la contrasena son obligatorios"
        }), 400

    user = User.query.filter_by(email=email).first()

    if user is None or not check_password_hash(user.password, password):
        return jsonify({
            "message": "Correo o contrasena incorrectos"
        }), 401

    token = serializer.dumps({
        "user_id": user.id
    })

    return jsonify({
        "message": "Inicio de sesion correcto",
        "token": token,
        "user": user.to_dict()
    }), 200


# ==========================================
# CONSULTAR USUARIO AUTENTICADO
# ==========================================

@app.get("/api/auth/me")
@token_required
def current_user():

    return jsonify({
        "message": "Usuario autenticado correctamente",
        "user": request.current_user.to_dict()
    }), 200


# ==========================================
# CREAR TRANSACCION
# ==========================================

@app.post("/api/transactions")
@token_required
def create_transaction():

    data = request.get_json(silent=True) or {}

    transaction_data, error = validate_transaction_data(data)

    if error:
        return jsonify({"message": error}), 400

    new_transaction = Transaction(
        description=transaction_data["description"],
        amount=transaction_data["amount"],
        category=transaction_data["category"],
        transaction_type=transaction_data["transaction_type"],
        user_id=request.current_user.id
    )

    db.session.add(new_transaction)
    db.session.commit()

    return jsonify({
        "message": "Transaccion creada correctamente",
        "transaction": new_transaction.to_dict()
    }), 201


# ==========================================
# CONSULTAR TODAS LAS TRANSACCIONES PROPIAS
# ==========================================

@app.get("/api/transactions")
@token_required
def get_transactions():

    transactions = Transaction.query.filter_by(
        user_id=request.current_user.id
    ).order_by(Transaction.id.desc()).all()

    return jsonify({
        "message": "Transacciones consultadas correctamente",
        "transactions": [
            transaction.to_dict()
            for transaction in transactions
        ]
    }), 200


# ==========================================
# CONSULTAR UNA TRANSACCION PROPIA
# ==========================================

@app.get("/api/transactions/<int:transaction_id>")
@token_required
def get_transaction(transaction_id):

    transaction = Transaction.query.filter_by(
        id=transaction_id,
        user_id=request.current_user.id
    ).first()

    if transaction is None:
        return jsonify({
            "message": "Transaccion no encontrada"
        }), 404

    return jsonify({
        "message": "Transaccion consultada correctamente",
        "transaction": transaction.to_dict()
    }), 200


# ==========================================
# ACTUALIZAR UNA TRANSACCION PROPIA
# ==========================================

@app.put("/api/transactions/<int:transaction_id>")
@token_required
def update_transaction(transaction_id):

    transaction = Transaction.query.filter_by(
        id=transaction_id,
        user_id=request.current_user.id
    ).first()

    if transaction is None:
        return jsonify({
            "message": "Transaccion no encontrada"
        }), 404

    data = request.get_json(silent=True) or {}

    transaction_data, error = validate_transaction_data(
        data,
        partial=True
    )

    if error:
        return jsonify({"message": error}), 400

    if not transaction_data:
        return jsonify({
            "message": "Debes enviar al menos un campo para actualizar"
        }), 400

    for field, value in transaction_data.items():
        setattr(transaction, field, value)

    db.session.commit()

    return jsonify({
        "message": "Transaccion actualizada correctamente",
        "transaction": transaction.to_dict()
    }), 200


# ==========================================
# ELIMINAR UNA TRANSACCION PROPIA
# ==========================================

@app.delete("/api/transactions/<int:transaction_id>")
@token_required
def delete_transaction(transaction_id):

    transaction = Transaction.query.filter_by(
        id=transaction_id,
        user_id=request.current_user.id
    ).first()

    if transaction is None:
        return jsonify({
            "message": "Transaccion no encontrada"
        }), 404

    db.session.delete(transaction)
    db.session.commit()

    return jsonify({
        "message": "Transaccion eliminada correctamente"
    }), 200


# ==========================================
# CONSULTAR PERFIL FINANCIERO
# ==========================================

@app.get("/api/profile")
@token_required
def get_profile():

    profile = UserProfile.query.filter_by(
        user_id=request.current_user.id
    ).first()

    return jsonify({
        "message": "Consulta de perfil realizada correctamente",
        "profile": profile.to_dict() if profile else None
    }), 200


# ==========================================
# CREAR O ACTUALIZAR PERFIL FINANCIERO
# ==========================================


@app.put("/api/profile")
@token_required

def save_profile():

    data = request.get_json(silent=True)

    if not isinstance(data, dict):
        return jsonify({
            "message": "Debes enviar un JSON valido"
        }), 400

    required_fields = [
        "occupation",
        "financial_goal",
        "monthly_income_range",
        "monthly_expense_range",
        "saving_habit",
        "main_challenge"
    ]

    for field in required_fields:
        value = data.get(field)

        if not isinstance(value, str) or not value.strip():
            return jsonify({
                "message": f"El campo {field} es obligatorio"
            }), 400

    optional_goal = data.get("savings_goal", "")

    if optional_goal is None:
        optional_goal = ""

    if not isinstance(optional_goal, str):
        return jsonify({
            "message": "La meta de ahorro debe ser texto"
        }), 400

    profile = UserProfile.query.filter_by(
        user_id=request.current_user.id
    ).first()

    accumulated_value = data.get(
        "savings_accumulated",
        profile.savings_accumulated if profile else 0
    )

    if isinstance(accumulated_value, bool):
        return jsonify({
            "message": "El ahorro acumulado debe ser un numero valido"
        }), 400

    try:
        accumulated_value = float(accumulated_value)
    except (ValueError, TypeError):
        return jsonify({
            "message": "El ahorro acumulado debe ser un numero valido"
        }), 400

    if not math.isfinite(accumulated_value) or accumulated_value < 0:
        return jsonify({
            "message": "El ahorro acumulado no puede ser negativo"
        }), 400

    profile_data = {
        "occupation": data["occupation"].strip(),
        "financial_goal": data["financial_goal"].strip(),
        "monthly_income_range": data["monthly_income_range"].strip(),
        "monthly_expense_range": data["monthly_expense_range"].strip(),
        "saving_habit": data["saving_habit"].strip(),
        "main_challenge": data["main_challenge"].strip(),
        "savings_goal": optional_goal.strip(),
        "savings_accumulated": accumulated_value
    }

    limits = {
        "occupation": 80,
        "financial_goal": 120,
        "monthly_income_range": 80,
        "monthly_expense_range": 80,
        "saving_habit": 80,
        "main_challenge": 120,
        "savings_goal": 100
    }

    for field, limit in limits.items():
        if len(profile_data[field]) > limit:
            return jsonify({
                "message": f"El campo {field} supera la longitud permitida"
            }), 400

    if profile is None:
        profile = UserProfile(
            user_id=request.current_user.id,
            **profile_data
        )
        db.session.add(profile)

    else:
        for field, value in profile_data.items():
            setattr(profile, field, value)

    db.session.commit()

    return jsonify({
        "message": "Perfil financiero guardado correctamente",
        "profile": profile.to_dict()
    }), 200


# ==========================================
# CREAR OBLIGACION DE PAGO
# ==========================================

@app.post("/api/obligations")
@token_required
def create_obligation():

    data = request.get_json(silent=True)

    obligation_data, error = validate_obligation_data(data)

    if error:
        return jsonify({"message": error}), 400

    status = obligation_data.get("status", "pendiente")

    new_obligation = PaymentObligation(
        title=obligation_data["title"],
        description=obligation_data.get("description"),
        amount=obligation_data["amount"],
        category=obligation_data["category"],
        due_date=obligation_data["due_date"],
        status=status,
        paid_at=datetime.utcnow() if status == "pagada" else None,
        user_id=request.current_user.id
    )

    db.session.add(new_obligation)
    db.session.commit()

    return jsonify({
        "message": "Obligacion registrada correctamente",
        "obligation": new_obligation.to_dict()
    }), 201


# ==========================================
# CONSULTAR OBLIGACIONES PROPIAS
# ==========================================

@app.get("/api/obligations")
@token_required
def get_obligations():

    status = request.args.get("status")

    query = PaymentObligation.query.filter_by(
        user_id=request.current_user.id
    )

    if status:
        status = status.strip().lower()

        if status not in ["pendiente", "pagada"]:
            return jsonify({
                "message": "El filtro debe ser pendiente o pagada"
            }), 400

        query = query.filter_by(status=status)

    obligations = query.order_by(
        PaymentObligation.due_date.asc(),
        PaymentObligation.id.desc()
    ).all()

    return jsonify({
        "message": "Obligaciones consultadas correctamente",
        "obligations": [
            obligation.to_dict()
            for obligation in obligations
        ]
    }), 200


# ==========================================
# CONSULTAR UNA OBLIGACION PROPIA
# ==========================================

@app.get("/api/obligations/<int:obligation_id>")
@token_required
def get_obligation(obligation_id):

    obligation = PaymentObligation.query.filter_by(
        id=obligation_id,
        user_id=request.current_user.id
    ).first()

    if obligation is None:
        return jsonify({
            "message": "Obligacion no encontrada"
        }), 404

    return jsonify({
        "message": "Obligacion consultada correctamente",
        "obligation": obligation.to_dict()
    }), 200


# ==========================================
# ACTUALIZAR UNA OBLIGACION PROPIA
# ==========================================

@app.put("/api/obligations/<int:obligation_id>")
@token_required
def update_obligation(obligation_id):

    obligation = PaymentObligation.query.filter_by(
        id=obligation_id,
        user_id=request.current_user.id
    ).first()

    if obligation is None:
        return jsonify({
            "message": "Obligacion no encontrada"
        }), 404

    data = request.get_json(silent=True)

    obligation_data, error = validate_obligation_data(
        data,
        partial=True
    )

    if error:
        return jsonify({"message": error}), 400

    if not obligation_data:
        return jsonify({
            "message": "Debes enviar al menos un campo para actualizar"
        }), 400

    for field, value in obligation_data.items():
        setattr(obligation, field, value)

    if "status" in obligation_data:
        if obligation_data["status"] == "pagada":
            if obligation.paid_at is None:
                obligation.paid_at = datetime.utcnow()
        else:
            obligation.paid_at = None

    db.session.commit()

    return jsonify({
        "message": "Obligacion actualizada correctamente",
        "obligation": obligation.to_dict()
    }), 200


# ==========================================
# ELIMINAR UNA OBLIGACION PROPIA
# ==========================================

@app.delete("/api/obligations/<int:obligation_id>")
@token_required
def delete_obligation(obligation_id):

    obligation = PaymentObligation.query.filter_by(
        id=obligation_id,
        user_id=request.current_user.id
    ).first()

    if obligation is None:
        return jsonify({
            "message": "Obligacion no encontrada"
        }), 404

    db.session.delete(obligation)
    db.session.commit()

    return jsonify({
        "message": "Obligacion eliminada correctamente"
    }), 200



# ==========================================
# ASISTENTE FINANCIERO CON INTELIGENCIA ARTIFICIAL
# ==========================================

@app.post("/api/chatbot")
@token_required
def chatbot():
    # Verificar que la API Key de Gemini este configurada.
    if gemini_client is None:
        return jsonify({
            "message": "El asistente de IA no esta configurado en el servidor"
        }), 503

    data = request.get_json(silent=True)

    if not isinstance(data, dict):
        return jsonify({
            "message": "Debes enviar un JSON valido"
        }), 400

    user_message = data.get("message")

    if not isinstance(user_message, str) or not user_message.strip():
        return jsonify({
            "message": "Escribe una pregunta para el asistente"
        }), 400

    user_message = user_message.strip()

    if len(user_message) > 2000:
        return jsonify({
            "message": "El mensaje no puede superar los 2000 caracteres"
        }), 400

    user_id = request.current_user.id

    try:
        # Consultar unicamente la informacion del usuario autenticado.
        profile = UserProfile.query.filter_by(
            user_id=user_id
        ).first()

        transaction_summary = (
            db.session.query(
                Transaction.transaction_type,
                Transaction.category,
                db.func.sum(Transaction.amount).label("total"),
                db.func.count(Transaction.id).label("quantity")
            )
            .filter_by(user_id=user_id)
            .group_by(
                Transaction.transaction_type,
                Transaction.category
            )
            .all()
        )

        recent_transactions = (
            Transaction.query
            .filter_by(user_id=user_id)
            .order_by(Transaction.id.desc())
            .limit(30)
            .all()
        )

        obligations = (
            PaymentObligation.query
            .filter_by(user_id=user_id)
            .order_by(PaymentObligation.due_date.asc())
            .limit(30)
            .all()
        )

        financial_context = {
            "perfil_financiero": profile.to_dict() if profile else None,
            "resumen_transacciones_por_tipo_y_categoria": [
                {
                    "tipo": row.transaction_type,
                    "categoria": row.category,
                    "total": round(float(row.total or 0), 2),
                    "cantidad": int(row.quantity)
                }
                for row in transaction_summary
            ],
            "ultimas_transacciones": [
                {
                    "descripcion": transaction.description,
                    "monto": transaction.amount,
                    "categoria": transaction.category,
                    "tipo": transaction.transaction_type
                }
                for transaction in recent_transactions
            ],
            "obligaciones": [
                {
                    "titulo": obligation.title,
                    "descripcion": obligation.description,
                    "monto": obligation.amount,
                    "categoria": obligation.category,
                    "fecha_vencimiento": obligation.due_date.isoformat(),
                    "estado": obligation.status,
                    "vencida": (
                        obligation.status == "pendiente"
                        and obligation.due_date < date.today()
                    )
                }
                for obligation in obligations
            ]
        }



        system_instructions = """
Eres Wise Assistant, el asistente financiero educativo de Wise Wallet.
Responde siempre en español, con un tono amable, natural, claro y respetuoso.

OBJETIVO
Ayuda al usuario a comprender sus finanzas, identificar aspectos importantes
y tomar decisiones informadas utilizando exclusivamente los datos disponibles.

USO DEL PERFIL FINANCIERO
El contexto puede incluir un perfil financiero registrado por el usuario.
Utiliza esta información para personalizar tus respuestas y recomendaciones.

- Ocupación: adapta los ejemplos y explicaciones a la situación del usuario
  cuando sea relevante, sin hacer suposiciones sobre sus ingresos.
- Objetivo financiero: relaciona las recomendaciones con el propósito que
  el usuario desea alcanzar.
- Rango de ingresos: tenlo en cuenta para orientar sugerencias realistas,
  pero recuerda que es un rango declarado y no un ingreso exacto comprobado.
- Rango de gastos: úsalo como referencia general, sin asumir que representa
  todos los gastos reales del usuario.
- Hábito de ahorro: adapta las recomendaciones al nivel de experiencia
  y constancia que el usuario declara.
- Principal desafío financiero: prioriza consejos relacionados con esa
  dificultad cuando la pregunta lo permita.
- Meta de ahorro: tenla presente al hablar de planificación y objetivos.
  Si contiene una cantidad identificable, puedes mencionarla respetando
  el valor registrado. Si es un texto ambiguo, no inventes una cantidad.

USO DEL AHORRO ACUMULADO Y LA META DE AHORRO

- Utiliza el campo savings_accumulated del perfil financiero como el ahorro acumulado que el usuario declara tener actualmente.
- Este valor es informado manualmente por el usuario. No lo presentes como un saldo bancario verificado.
- Compara savings_accumulated con savings_goal cuando la meta contenga una cantidad monetaria que pueda identificarse claramente.
- Si ambos valores son válidos y la meta es mayor que cero, calcula cuánto falta para alcanzar la meta restando el ahorro acumulado a la meta. Si el resultado es negativo, indica que la meta ya fue alcanzada o superada.
- Calcula el porcentaje de avance dividiendo el ahorro acumulado entre la meta y multiplicando por 100.
- Si el porcentaje supera el 100 %, puedes indicar que el usuario superó su meta, sin presentar un avance limitado al 100 % como si fuera el valor real.
- Si la meta no contiene una cantidad monetaria clara o el ahorro acumulado no está disponible, no inventes cifras ni porcentajes.
- No calcules el ahorro acumulado restando los gastos registrados a los ingresos registrados.
- No confundas el ahorro acumulado con dinero disponible para gastar.
- Antes de recomendar aumentar el ahorro, considera las obligaciones pendientes y vencidas. Prioriza las obligaciones urgentes cuando corresponda.
- Propón recomendaciones graduales y realistas para mantener o aumentar el ahorro, teniendo en cuenta el hábito de ahorro y la principal dificultad del usuario.
- Utiliza separadores de miles con puntos y el símbolo $ en todas las cantidades monetarias.

REGLAS PARA PERSONALIZAR RECOMENDACIONES
- No repitas todos los datos del perfil en cada respuesta.
- Utiliza únicamente los datos que sean relevantes para la pregunta.
- Si el usuario tiene una meta de ahorro, orienta las recomendaciones
  hacia ella sin asegurar que pueda alcanzarla en un plazo determinado.
- Si declara dificultades para ahorrar, ofrece pasos pequeños y realistas.
- Si su principal desafío son las deudas, prioriza la revisión de obligaciones
  y compromisos pendientes antes de sugerir nuevos ahorros.
- Si sus ingresos son variables o limitados, evita recomendar cantidades
  fijas de ahorro sin información suficiente.
- Si el objetivo financiero es comprar algo, viajar, estudiar o pagar deudas,
  adapta las sugerencias a ese objetivo.
- No confundas los rangos declarados en el perfil con los totales calculados
  a partir de las transacciones.
- Si el perfil no existe o algún campo está vacío, no inventes información.
- Si el usuario actualiza su perfil, utiliza los datos más recientes que
  aparezcan en el contexto financiero.

REGLAS FINANCIERAS
- Utiliza únicamente la información del contexto financiero proporcionado.
- No inventes movimientos, ingresos, gastos, fechas, saldos ni cálculos.
- Distingue los ingresos propios, como salarios, del dinero recibido mediante
  préstamos. Un préstamo recibido no es salario ni ganancia.
- No reclasifiques ni modifiques los movimientos registrados.
- Separa los gastos registrados de las obligaciones pendientes.
- No sumes obligaciones pendientes al total de gastos.
- No cuentes dos veces una obligación pagada si podría estar representada
  en una transacción.
- Las transacciones no tienen fechas. No afirmes tendencias, promedios,
  presupuestos mensuales ni comportamientos por periodos.
- Puedes mencionar las fechas de vencimiento de las obligaciones.
- No supongas que los registros representan todos los movimientos del usuario.
- No calcules dinero disponible para gastar o ahorrar si faltan datos para
  hacerlo de forma segura.
- Si no hay información suficiente, explícalo brevemente.
- No afirmes que puedes crear, modificar o eliminar registros.
- Nunca solicites contraseñas, claves bancarias ni datos completos de tarjetas.
- No recomiendes inversiones específicas ni prometas rendimientos.
- Tus respuestas son educativas y no sustituyen asesoramiento financiero
  profesional.

FORMATO DE LAS CANTIDADES
- Presenta las cantidades monetarias con el símbolo $ y puntos como
  separadores de miles.
- Ejemplo: $3.400.000, $150.000, $85.000 y $235.650.
- No presentes cantidades monetarias como 3400000 o 150000.
- Conserva los valores exactos registrados; no redondees ni alteres montos.
- No apliques formato monetario a fechas, cantidades de movimientos o
  porcentajes.
- Si el contexto no permite confirmar una moneda, no inventes una distinta.

ESTILO DE RESPUESTA
- Responde siempre en español.
- Utiliza texto sencillo, sin Markdown, asteriscos, negritas ni bloques de código.
- Organiza las respuestas con títulos cortos cuando ayuden a comprender
  la información.
- Separa los temas en párrafos breves.
- Evita párrafos largos y explicaciones repetitivas.
- Responde primero la pregunta concreta del usuario.
- Incluye únicamente los datos y explicaciones relevantes para esa pregunta.
- Cuando presentes recomendaciones, prioriza las más importantes y explica
  brevemente por qué son útiles.
- No repitas el saludo ni te presentes en cada respuesta.
- No añadas advertencias genéricas al final de todas las respuestas.
- Evita repetir información que ya explicaste en la misma respuesta.
- Mantén un lenguaje cercano, profesional y fácil de entender.

RECOMENDACIONES
- Ofrece sugerencias realistas y relacionadas con la información disponible.
- Considera las obligaciones pendientes antes de recomendar ahorrar o gastar.
- No propongas cantidades de ahorro sin datos suficientes para justificarlas.
- No conviertas cada respuesta en una lista de recomendaciones si el usuario
  solo solicita un dato o una explicación puntual.
"""


        prompt = (
            "Contexto financiero del usuario (datos privados de su propia cuenta):\n"
            + json.dumps(financial_context, ensure_ascii=False)
            + "\n\nPregunta del usuario:\n"
            + user_message
        )

        response = gemini_client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config={
                "system_instruction": system_instructions,
                "max_output_tokens": 500,
                "temperature": 0.7
            }
        )

        assistant_message = (response.text or "").strip()

        if not assistant_message:
            return jsonify({
                "message": "No fue posible generar una respuesta. Intenta nuevamente."
            }), 502

        return jsonify({
            "message": "Respuesta generada correctamente",
            "reply": assistant_message
        }), 200

    except genai_errors.APIError as error:
        status_code = getattr(error, "code", None)

        if status_code == 429:
            app.logger.warning(
                "Gemini alcanzo el limite de solicitudes (HTTP 429)."
            )
            return jsonify({
                "message": (
                    "Se alcanzo el limite gratuito de solicitudes de Gemini. "
                    "Espera un momento e intenta nuevamente."
                )
            }), 429

        if status_code in (503, 504):
            app.logger.warning(
                "Gemini no esta disponible temporalmente (HTTP %s).",
                status_code
            )
            response = jsonify({
                "message": (
                    "El asistente esta recibiendo muchas solicitudes o "
                    "no esta disponible temporalmente. Espera unos segundos "
                    "e intenta nuevamente."
                )
            })
            response.headers["Retry-After"] = "10"
            return response, 503

        app.logger.exception("Gemini devolvio un error de API.")

        if status_code in (400, 401, 403):
            return jsonify({
                "message": (
                    "Gemini rechazo la solicitud. Verifica la clave API "
                    "y la configuracion del modelo."
                )
            }), 503

        return jsonify({
            "message": "El servicio de IA presento un error. Intenta nuevamente."
        }), 502

    except Exception:
        db.session.rollback()
        app.logger.exception("Error inesperado en el endpoint del chatbot.")
        return jsonify({
            "message": "Ocurrio un error al procesar tu consulta."
        }), 500


# ==========================================
# CREAR TABLAS DE LA BASE DE DATOS
# ==========================================


with app.app_context():
    db.create_all()

    # Migracion: agregar ahorro acumulado a perfiles existentes.
    inspector = inspect(db.engine)

    profile_columns = {
        column["name"]
        for column in inspector.get_columns("user_profiles")
    }

    if "savings_accumulated" not in profile_columns:
        with db.engine.begin() as connection:
            connection.execute(db.text("""
                ALTER TABLE user_profiles
                ADD COLUMN savings_accumulated FLOAT NOT NULL DEFAULT 0
            """))

        app.logger.info(
            "Migracion completada: savings_accumulated agregada."
        )

# ==========================================
# EJECUTAR SERVIDOR
# ==========================================

if __name__ == "__main__":

    app.run(debug=True, host="0.0.0.0", port=5000)
