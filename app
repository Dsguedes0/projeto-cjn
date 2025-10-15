#main code / app.py

import os
import requests
from flask import Flask, request, jsonify
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)


HUGGINGFACE_API_TOKEN = os.getenv("HUGGINGFACE_API_TOKEN")

HUGGINGFACE_API_URL = "https://api-inference.huggingface.co/models/stabilityai/stable-diffusion-xl-base-1.0"
HEADERS = {"Authorization": f"Bearer {HUGGINGFACE_API_TOKEN}"}

if not HUGGINGFACE_API_TOKEN:
    print("WARNING: HUGGINGFACE_API_TOKEN not found in .env file.")
    print("Image generation will fail without a valid token.")
    print("Please get your token from https://huggingface.co/settings/tokens")

def generate_image(prompt: str) -> str | None:
    """
    Generates an image using the Hugging Face Inference API.

    Args:
        prompt: The text prompt for image generation.

    Returns:
        The URL of the generated image (if successful), or None.
    """
    if not HUGGINGFACE_API_TOKEN:
        print("Error: HUGGINGFACE_API_TOKEN is not set.")
        return None

    payload = {"inputs": prompt}
    try:
        response = requests.post(HUGGINGFACE_API_URL, headers=HEADERS, json=payload)
        response.raise_for_status()  # Raise an exception for HTTP errors (4xx or 5xx)


        return f"Imagem gerada com sucesso para o prompt: '{prompt}'. (A URL da imagem seria fornecida aqui após o upload para um serviço de hospedagem de arquivos)."

    except requests.exceptions.RequestException as e:
        app.logger.error(f"Error calling Hugging Face API: {e}")
        return None
    except Exception as e:
        app.logger.error(f"An unexpected error occurred: {e}")
        return None

# --- WhatsApp Webhook Endpoint (Conceptual) ---
# Lembre-se: Isso é conceitual. A integração real com WhatsApp Business API
# geralmente exige um provedor pago.
@app.route('/whatsapp_webhook', methods=['POST'])
def whatsapp_webhook():
    try:
        data = request.get_json()
        app.logger.info(f"Received WhatsApp webhook data: {data}")

        user_message = ""
        if 'Body' in data: # Exemplo para Twilio
            user_message = data.get('Body', '').strip()
        elif 'entry' in data and data['entry']: # Exemplo para Meta Webhooks
            for entry in data['entry']:
                for change in entry.get('changes', []):
                    if change.get('field') == 'messages':
                        for message in change.get('value', {}).get('messages', []):
                            if message.get('type') == 'text':
                                user_message = message['text']['body'].strip()
                                break
                    if user_message: break
                if user_message: break

        if not user_message:
            return jsonify({"status": "error", "message": "No valid message found in webhook"}), 200

        app.logger.info(f"User message received: {user_message}")

        image_response = generate_image(user_message)

        response_text = ""
        if image_response:
            response_text = f"Aqui está a imagem que eu criei para '{user_message}':\n{image_response}"
        else:
            response_text = "Desculpe, não consegui gerar a imagem. Por favor, tente novamente mais tarde ou verifique minha configuração."

        app.logger.info(f"Sending response: {response_text}")

        return jsonify({"status": "success", "response": response_text}), 200

    except Exception as e:
        app.logger.error(f"Error processing WhatsApp webhook: {e}", exc_info=True)
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/')
def home():
    return "Olá! Esta é a API para gerar imagens. Envie mensagens para /whatsapp_webhook."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
