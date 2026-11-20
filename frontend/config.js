// =============================================================================
// Configuración del Frontend - Conexión con AWS Serverless
// =============================================================================
// Estos valores son generados automáticamente tras ejecutar "terraform apply"

window.APP_CONFIG = {
  // URL base de tu API Gateway HTTP (Reemplazar con la salida de Terraform: api_gateway_url)
  API_BASE_URL: "https://your-api-id.execute-api.us-east-1.amazonaws.com",

  // Parámetros de Amazon Cognito para autenticación docente
  COGNITO_USER_POOL_ID: "us-east-1_exampleId",
  COGNITO_CLIENT_ID: "exampleAppClientId12345",
  AWS_REGION: "us-east-1",

  // Modo simulación local (true = usa backend simulado si no hay conexión; false = llamadas reales a AWS)
  USE_MOCK_FALLBACK: true
};
