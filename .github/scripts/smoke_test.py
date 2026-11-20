#!/usr/bin/env python3
"""
Script de Pruebas de Humo (Smoke Tests) E2E para el Sistema de Citas Escolares.
Verifica que tanto el Frontend (CloudFront + S3) como el Backend (API Gateway + Lambda)
estén en línea, accesibles y respondiendo correctamente tras el despliegue.
"""

import sys
import time
import argparse
import urllib.request
import urllib.error
import json

def test_endpoint(name, url, expected_status=200, check_fn=None, max_retries=20, delay_sec=5):
    print(f"\n🔍 [PROBANDO] {name}: {url}")
    for attempt in range(1, max_retries + 1):
        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "GitHubActions-SmokeTest/1.0"}
            )
            with urllib.request.urlopen(req, timeout=10) as response:
                status = response.getcode()
                body = response.read().decode("utf-8")

                if status == expected_status:
                    if check_fn:
                        is_ok, msg = check_fn(body)
                        if not is_ok:
                            print(f"   ⚠️ Intento {attempt}/{max_retries}: Validación de contenido falló: {msg}")
                            time.sleep(delay_sec)
                            continue
                    print(f"   ✅ [EXITOSO] HTTP {status} recibido en intento {attempt}.")
                    return True
                else:
                    print(f"   ⚠️ Intento {attempt}/{max_retries}: HTTP {status} (esperado {expected_status})")
        except urllib.error.HTTPError as e:
            print(f"   ⚠️ Intento {attempt}/{max_retries}: HTTP Error {e.code} - {e.reason}")
        except urllib.error.URLError as e:
            print(f"   ⚠️ Intento {attempt}/{max_retries}: Error de red/conexión: {e.reason}")
        except Exception as e:
            print(f"   ⚠️ Intento {attempt}/{max_retries}: Excepción inesperada: {str(e)}")

        if attempt < max_retries:
            time.sleep(delay_sec)

    print(f"   ❌ [FALLÓ] No se pudo verificar '{name}' tras {max_retries} intentos.")
    return False

def main():
    parser = argparse.ArgumentParser(description="Verificar disponibilidad del sitio tras despliegue.")
    parser.add_argument("--frontend-url", required=True, help="URL pública de CloudFront")
    parser.add_argument("--api-url", required=True, help="URL base de API Gateway")
    args = parser.parse_args()

    frontend_url = args.frontend_url.rstrip("/")
    api_url = args.api_url.rstrip("/")

    print("=" * 70)
    print("🚀 INICIANDO PRUEBAS DE DISPONIBILIDAD (SMOKE TESTS POST-DESPLIEGUE)")
    print(f"   • Frontend URL:    {frontend_url}")
    print(f"   • API Gateway URL: {api_url}")
    print("=" * 70)

    results = []

    # 1. Verificar Frontend HTML
    def validate_html(body):
        if "html" in body.lower() and ("citas" in body.lower() or "escolar" in body.lower()):
            return True, "HTML de la aplicación encontrado"
        return False, "El contenido no parece ser el HTML esperado"

    results.append(test_endpoint(
        name="1. Frontend Web App (HTML en CloudFront)",
        url=frontend_url,
        expected_status=200,
        check_fn=validate_html,
        max_retries=24, # Hasta 2 minutos para propagación de CDN
        delay_sec=5
    ))

    # 2. Verificar config.js inyectado dinámicamente
    def validate_config(body):
        if "APP_CONFIG" in body and "API_BASE_URL" in body:
            return True, "Variables de configuración inyectadas correctamente"
        return False, "config.js no contiene APP_CONFIG"

    results.append(test_endpoint(
        name="2. Configuración Dinámica (config.js en CloudFront)",
        url=f"{frontend_url}/config.js",
        expected_status=200,
        check_fn=validate_config,
        max_retries=10,
        delay_sec=4
    ))

    # 3. Verificar Backend Health Check
    def validate_health(body):
        try:
            data = json.loads(body)
            if data.get("status") == "healthy":
                return True, "Health check reporta 'healthy'"
            return False, f"Status inesperado: {data.get('status')}"
        except Exception:
            return False, "La respuesta no es JSON válido"

    results.append(test_endpoint(
        name="3. Backend Health Check (GET /health en API Gateway)",
        url=f"{api_url}/health",
        expected_status=200,
        check_fn=validate_health,
        max_retries=10,
        delay_sec=3
    ))

    # 4. Verificar Endpoint Público de Slots
    def validate_slots(body):
        try:
            data = json.loads(body)
            if "slots_disponibles" in data:
                return True, f"Horarios disponibles obtenidos: {len(data['slots_disponibles'])} slots"
            return False, "Respuesta no contiene 'slots_disponibles'"
        except Exception:
            return False, "La respuesta no es JSON válido"

    results.append(test_endpoint(
        name="4. Consulta Pública de Horarios (GET /slots en API Gateway)",
        url=f"{api_url}/slots?teacher_id=prof-garcia&fecha=2026-12-01",
        expected_status=200,
        check_fn=validate_slots,
        max_retries=10,
        delay_sec=3
    ))

    print("\n" + "=" * 70)
    if all(results):
        print("🎉 ¡TODAS LAS PRUEBAS DE DISPONIBILIDAD PASARON SATISFACTORIAMENTE!")
        print("   El sitio web y los microservicios backend están completamente operativos.")
        print("=" * 70)
        sys.exit(0)
    else:
        print("💥 AL MENOS UNA PRUEBA DE DISPONIBILIDAD FALLÓ.")
        print("   Revisa los logs anteriores para depurar la conexión del servicio.")
        print("=" * 70)
        sys.exit(1)

if __name__ == "__main__":
    main()
