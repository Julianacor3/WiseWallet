
from pathlib import Path
from functools import wraps
from datetime import date, datetime
import math
import os

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

    profile_data = {
        "occupation": data["occupation"].strip(),
        "financial_goal": data["financial_goal"].strip(),
        "monthly_income_range": data["monthly_income_range"].strip(),
        "monthly_expense_range": data["monthly_expense_range"].strip(),
        "saving_habit": data["saving_habit"].strip(),
        "main_challenge": data["main_challenge"].strip(),
        "savings_goal": optional_goal.strip()
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

    for field, value in profile_data.items():
        if len(value) > limits[field]:
            return jsonify({
                "message": f"El campo {field} supera la longitud permitida"
            }), 400

    profile = UserProfile.query.filter_by(
        user_id=request.current_user.id
    ).first()

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
# CREAR TABLAS DE LA BASE DE DATOS
# ==========================================

with app.app_context():
    db.create_all()


# ==========================================
# EJECUTAR SERVIDOR
# ==========================================

if __name__ == "__main__":

    app.run(debug=True, host="0.0.0.0", port=5000)
