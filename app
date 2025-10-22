#main code / app.py

import os
import requests
from flask import Flask, request, jsonify, send_from_directory, render_template
from dotenv import load_dotenv
import uuid
import logging
from datetime import datetime

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                    handlers=[
                        logging.FileHandler("app.log"),
                        logging.StreamHandler()
                    ])
app_logger = logging.getLogger(__name__)

load_dotenv()
print(f"Token HF lido do .env: {os.getenv('HF_API_TOKEN')}")

app = Flask(__name__, static_folder='static', template_folder='templates')


HUGGINGFACE_API_TOKEN = os.getenv("HUGGINGFACE_API_TOKEN")
HUGGINGFACE_API_URL = "https://api-inference.huggingface.co/models/stabilityai/stable-diffusion-xl-base-1.0"
HEADERS = {"Authorization": f"Bearer {HUGGINGFACE_API_TOKEN}"}

if not HUGGINGFACE_API_TOKEN:
    app_logger.warning(" HUGGINGFACE_API_TOKEN não encontrado no arquivo .env.")
    app_logger.warning(" A geração de imagens falhará sem um token válido.")
    app_logger.warning(" Por favor, obtenha seu token em https://huggingface.co/settings/tokens")

GENERATED_IMAGES_DIR = 'generated_images'
if not os.path.exists(GENERATED_IMAGES_DIR):
    os.makedirs(GENERATED_IMAGES_DIR)
    app_logger.info(f"Diretório '{GENERATED_IMAGES_DIR}' criado para armazenar imagens geradas.")


def generate_image(prompt: str) -> str | None:

    if not HUGGINGFACE_API_TOKEN:
        app_logger.error(" Erro: HUGGINGFACE_API_TOKEN não está configurado.")
        return None

    if not prompt:
        app_logger.warning("Prompt vazio recebido para geração de imagem.")
        return None

    payload = {"inputs": prompt}
    app_logger.info(f"Iniciando geração de imagem para o prompt: '{prompt[:50]}...'") 
    try:
        response = requests.post(HUGGINGFACE_API_URL, headers=HEADERS, json=payload, timeout=60) 
        response.raise_for_status() 

        image_bytes = response.content

        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        image_filename = f"image_{timestamp}_{uuid.uuid4().hex[:8]}.png"
        image_path = os.path.join(GENERATED_IMAGES_DIR, image_filename)

        with open(image_path, "wb") as f:
            f.write(image_bytes)

        app_logger.info(f" Imagem salva localmente: {image_path}")
        return image_filename
    except requests.exceptions.HTTPError as http_err:
        app_logger.error(f" Erro HTTP ao chamar a API Hugging Face: {http_err} - Resposta: {response.text}")
        return None
    except requests.exceptions.ConnectionError as conn_err:
        app_logger.error(f" Erro de Conexão com a API Hugging Face: {conn_err}. Verifique sua conexão ou URL da API.")
        return None
    except requests.exceptions.Timeout as timeout_err:
        app_logger.error(f" Tempo esgotado (timeout) ao esperar resposta da API Hugging Face: {timeout_err}")
        return None
    except requests.exceptions.RequestException as req_err:
        app_logger.error(f" Erro geral de requisição com a API Hugging Face: {req_err}")
        return None
    except Exception as e:
        app_logger.error(f" Ocorreu um erro inesperado na geração de imagem: {e}", exc_info=True)
        return None

@app.route('/')
def home():
    app_logger.info("Acessada a rota / (home page).")
    return render_template('index.html')

@app.route('/generate', methods=['POST'])
def generate_image_endpoint():

    app_logger.info("Requisição POST recebida na rota /generate.")
    try:
        data = request.get_json()
        prompt = data.get('prompt')

        if not prompt:
            app_logger.warning("Requisição /generate sem prompt fornecido.")
            return jsonify({"status": "error", "message": "O prompt é obrigatório para gerar a imagem."}), 400

        if len(prompt) > 3000:
            app_logger.warning(f"Prompt muito longo recebido (tamanho: {len(prompt)}). Truncando para 500 caracteres.")
            prompt = prompt[:500]

        image_filename = generate_image(prompt)

        if image_filename:
            image_url = f"/generated_images/{image_filename}"
            app_logger.info(f"Imagem gerada com sucesso. URL: {image_url}")
            return jsonify({
                "status": "success",
                "image_url": image_url,
                "prompt": prompt
            }), 200
        else:
            app_logger.error("Falha na geração da imagem: A função generate_image retornou None.")
            return jsonify({"status": "error", "message": "Falha ao gerar a imagem. Por favor, tente novamente."}), 500

    except Exception as e:
        app_logger.error(f"Erro inesperado no endpoint /generate: {e}", exc_info=True)
        return jsonify({"status": "error", "message": f"Ocorreu um erro interno: {str(e)}"}), 500

@app.route('/generated_images/<filename>')
def serve_generated_image(filename):

    app_logger.info(f"Servindo imagem gerada: {filename}")
    try:
        return send_from_directory(GENERATED_IMAGES_DIR, filename)
    except FileNotFoundError:
        app_logger.error(f"Arquivo de imagem não encontrado: {filename}")
        return jsonify({"status": "error", "message": "Imagem não encontrada."}), 404
    except Exception as e:
        app_logger.error(f"Erro ao servir imagem {filename}: {e}", exc_info=True)
        return jsonify({"status": "error", "message": f"Ocorreu um erro ao buscar a imagem: {str(e)}"}), 500

if __name__ == '__main__':

    app_logger.info("Iniciando servidor Flask em modo de desenvolvimento...")
    app.run(host='0.0.0.0', port=5000, debug=True) 
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
