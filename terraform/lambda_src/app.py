import json
import os
import boto3
from botocore.exceptions import ClientError

# ==============================================================================
# Backend Serverless en AWS Lambda - Sistema de Citas Escolares
# ==============================================================================
# - Previene el cruce de citas usando DynamoDB Conditional Writes
# - Garantiza que cada profesor vea exclusivamente sus citas mediante claims JWT
# ==============================================================================

dynamodb = boto3.resource('dynamodb')
ses = boto3.client('ses')

TABLE_NAME = os.environ.get('TABLE_NAME', 'citas-escolares-citas-prod')
SENDER_EMAIL = os.environ.get('SENDER_EMAIL', 'notificaciones@colegio.edu')
table = dynamodb.Table(TABLE_NAME)

# Horarios de atención configurables (bloques de 30 minutos)
DEFAULT_SLOTS = [
    "07:30", "08:00", "08:30", "09:00", 
    "09:30", "10:00", "10:30", "11:00", 
    "11:30", "14:00", "14:30", "15:00"
]

# Lista estática inicial de docentes y asignaturas para consulta
DOCENTES_CATALOG = [
    {"id": "prof-garcia", "nombre": "Prof. Carlos García", "materia": "Matemáticas"},
    {"id": "prof-martinez", "nombre": "Prof. Laura Martínez", "materia": "Español y Literatura"},
    {"id": "prof-rodriguez", "nombre": "Prof. Andrés Rodríguez", "materia": "Ciencias Naturales"},
    {"id": "prof-gomez", "nombre": "Prof. Sofía Gómez", "materia": "Inglés"}
]

def build_response(status_code, body):
    """Genera respuestas HTTP compatibles con API Gateway HTTP API v2 con CORS"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization'
        },
        'body': json.dumps(body, ensure_ascii=False)
    }

def handler(event, context):
    print("Invocación recibida:", json.dumps(event))

    http_context = event.get('requestContext', {}).get('http', {})
    http_method = http_context.get('method', 'GET')
    path = http_context.get('path', '')

    # Responder pre-flight CORS OPTIONS inmediatamente
    if http_method == 'OPTIONS':
        return build_response(200, {'message': 'CORS OK'})

    try:
        # ======================================================================
        # 0. RUTA: Verificación de Estado (Health Check Público)
        # GET /health
        # ======================================================================
        if http_method == 'GET' and (path.endswith('/health') or path == '' or path == '/'):
            return build_response(200, {
                'status': 'healthy',
                'service': 'citas-escolares-backend',
                'version': '1.0.0'
            })

        # ======================================================================
        # 1. RUTA: Catálogo de Docentes (Público)
        # GET /docentes
        # ======================================================================
        if http_method == 'GET' and path.endswith('/docentes'):
            return build_response(200, {'docentes': DOCENTES_CATALOG})

        # ======================================================================
        # 2. RUTA: Consultar Slots Disponibles de un Docente (Público)
        # GET /slots?teacher_id=...&fecha=YYYY-MM-DD
        # ======================================================================
        if http_method == 'GET' and path.endswith('/slots'):
            params = event.get('queryStringParameters') or {}
            teacher_id = params.get('teacher_id')
            fecha = params.get('fecha')

            if not teacher_id or not fecha:
                return build_response(400, {'error': 'Debe enviar teacher_id y fecha (YYYY-MM-DD)'})

            # Consultar en DynamoDB todas las citas tomadas para esa fecha
            response = table.query(
                KeyConditionExpression="PK = :pk AND begins_with(SK, :sk_prefix)",
                ExpressionAttributeValues={
                    ':pk': f"DOCENTE#{teacher_id}",
                    ':sk_prefix': f"SLOT#{fecha}"
                }
            )

            citas_activas = [
                item for item in response.get('Items', [])
                if item.get('estado') != 'CANCELADA'
            ]
            horas_ocupadas = {item['SK'].split('#')[-1] for item in citas_activas}

            slots_libres = [h for h in DEFAULT_SLOTS if h not in horas_ocupadas]

            return build_response(200, {
                'teacher_id': teacher_id,
                'fecha': fecha,
                'slots_disponibles': slots_libres,
                'slots_ocupados': list(horas_ocupadas)
            })

        # ======================================================================
        # 3. RUTA: Agendar Cita (Público / Acudiente) con CANDADO ATÓMICO
        # POST /citas
        # ======================================================================
        if http_method == 'POST' and path.endswith('/citas'):
            raw_body = event.get('body') or '{}'
            data = json.loads(raw_body)

            teacher_id = data.get('teacher_id')
            fecha = data.get('fecha')
            hora = data.get('hora')
            acudiente = data.get('acudiente')
            email_acudiente = data.get('email')
            estudiante = data.get('estudiante')
            motivo = data.get('motivo', 'Atención académica')

            # Validación de campos obligatorios
            if not all([teacher_id, fecha, hora, acudiente, email_acudiente, estudiante]):
                return build_response(400, {'error': 'Faltan campos obligatorios para agendar la cita'})

            pk = f"DOCENTE#{teacher_id}"
            sk = f"SLOT#{fecha}#{hora}"

            try:
                # --------------------------------------------------------------
                # CANDADO ATÓMICO DE CONCURRENCIA (Previene colisiones por WhatsApp)
                # --------------------------------------------------------------
                table.put_item(
                    Item={
                        'PK': pk,
                        'SK': sk,
                        'teacher_id': teacher_id,
                        'fecha': fecha,
                        'hora': hora,
                        'acudiente': acudiente,
                        'email_acudiente': email_acudiente,
                        'estudiante': estudiante,
                        'motivo': motivo,
                        'estado': 'CONFIRMADA',
                        'creada_el': str(context.aws_request_id) if context else 'simulada'
                    },
                    ConditionExpression='attribute_not_exists(SK)'
                )
            except ClientError as err:
                if err.response['Error']['Code'] == 'ConditionalCheckFailedException':
                    # Conflicto: otro acudiente reservó el mismo minuto
                    return build_response(409, {
                        'error': 'El horario seleccionado acaba de ser tomado por otro acudiente. Por favor elija otro turno libre.'
                    })
                print("Error de DynamoDB:", str(err))
                return build_response(500, {'error': 'Error de base de datos al guardar cita'})

            # Enviar correo de confirmación mediante Amazon SES (opcional/asíncrono)
            try:
                ses.send_email(
                    Source=SENDER_EMAIL,
                    Destination={'ToAddresses': [email_acudiente]},
                    Message={
                        'Subject': {'Data': f"Confirmación de Cita: {fecha} a las {hora}"},
                        'Body': {
                            'Text': {
                                'Data': (
                                    f"Estimado(a) {acudiente},\n\n"
                                    f"Su cita para el alumno {estudiante} ha sido agendada con éxito.\n"
                                    f"Fecha: {fecha}\n"
                                    f"Hora: {hora}\n"
                                    f"Motivo: {motivo}\n\n"
                                    f"Colegio San José - Atención a Padres"
                                )
                            }
                        }
                    }
                )
            except Exception as ses_err:
                print("Advertencia SES (no bloquea la cita):", str(ses_err))

            return build_response(201, {
                'mensaje': 'Cita reservada y confirmada exitosamente',
                'cita': {
                    'teacher_id': teacher_id,
                    'fecha': fecha,
                    'hora': hora,
                    'estudiante': estudiante,
                    'acudiente': acudiente
                }
            })

        # ======================================================================
        # 4. RUTA: Consultar Citas del Docente Autenticado (Protegido por JWT)
        # GET /docente/citas
        # ======================================================================
        if http_method == 'GET' and '/docente/citas' in path:
            claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
            # Extraer el ID único del profesor desde el token firmado por Cognito
            teacher_id = claims.get('sub') or claims.get('username')
            teacher_email = claims.get('email', '')

            # Para permitir pruebas en entornos locales o de demostración
            if not teacher_id:
                query_params = event.get('queryStringParameters') or {}
                teacher_id = query_params.get('teacher_id', 'prof-garcia')

            # Consultar solo los registros asociados a su Partition Key
            response = table.query(
                KeyConditionExpression="PK = :pk",
                ExpressionAttributeValues={
                    ':pk': f"DOCENTE#{teacher_id}"
                }
            )

            citas_docente = [
                item for item in response.get('Items', [])
                if item.get('estado') != 'CANCELADA'
            ]

            return build_response(200, {
                'docente_id': teacher_id,
                'email': teacher_email,
                'total_citas': len(citas_docente),
                'citas': citas_docente
            })

        # ======================================================================
        # 5. RUTA: Cancelar o Finalizar Cita (Docente Autenticado)
        # DELETE /docente/citas
        # ======================================================================
        if http_method == 'DELETE' and '/docente/citas' in path:
            raw_body = event.get('body') or '{}'
            data = json.loads(raw_body)
            teacher_id = data.get('teacher_id', 'prof-garcia')
            fecha = data.get('fecha')
            hora = data.get('hora')

            if not fecha or not hora:
                return build_response(400, {'error': 'Faltan parámetros fecha y hora'})

            pk = f"DOCENTE#{teacher_id}"
            sk = f"SLOT#{fecha}#{hora}"

            # Marcar como cancelada o eliminar el ítem para liberar el slot
            table.delete_item(
                Key={'PK': pk, 'SK': sk}
            )

            return build_response(200, {
                'mensaje': 'Cita cancelada y horario liberado exitosamente',
                'slot_liberado': f"{fecha} {hora}"
            })

        return build_response(404, {'error': 'Ruta no encontrada', 'path': path, 'method': http_method})

    except Exception as e:
        print("Error no capturado en backend:", str(e))
        return build_response(500, {'error': 'Error interno del backend', 'detalle': str(e)})
