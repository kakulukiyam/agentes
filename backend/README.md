# Backend Serverless - AWS Lambda & DynamoDB

Este módulo contiene la lógica central del sistema de citas escolares:
- **Reserva Atómica Anti-Cruces:** Implementa `attribute_not_exists(SK)` en DynamoDB para garantizar que dos solicitudes concurrentes nunca reserven el mismo turno.
- **Segregación de Profesores:** Extrae el ID del profesor directamente desde los claims del token JWT de Cognito (`requestContext.authorizer.jwt.claims.sub`).
- **Notificaciones por Email:** Integración con Amazon SES.

## Estructura
- `app.py`: Manejador principal de la función Lambda con soporte para CORS y endpoints REST.
- `requirements.txt`: Declaración de dependencias (boto3 nativo).
