document.addEventListener('DOMContentLoaded', () => {
    const promptInput = document.getElementById('promptInput');
    const generateButton = document.getElementById('generateButton');
    const loadingDiv = document.getElementById('loading');
    const errorMessageDiv = document.getElementById('errorMessage');
    const imageDisplayDiv = document.getElementById('image-display');
    const generatedImage = document.getElementById('generatedImage');
    const displayedPrompt = document.getElementById('displayedPrompt');
    const downloadLink = document.getElementById('downloadLink');

    generateButton.addEventListener('click', async () => {
        const prompt = promptInput.value.trim();

        hideElement(imageDisplayDiv);
        hideElement(errorMessageDiv);
        generatedImage.src = '';
        generatedImage.alt = 'Imagem gerada pela IA';
        displayedPrompt.textContent = '';
        downloadLink.href = '#';

        if (!prompt) {
            showError('Por favor, digite um prompt para gerar a imagem.');
            return;
        }

        showElement(loadingDiv);

        try {
            const response = await fetch('/generate', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ prompt: prompt })
            });

            const data = await response.json();

            hideElement(loadingDiv); 

            if (response.ok && data.status === 'success') {
                generatedImage.src = data.image_url;
                generatedImage.alt = `Imagem gerada para: ${data.prompt}`;
                displayedPrompt.textContent = data.prompt;
                downloadLink.href = data.image_url; 
                showElement(imageDisplayDiv); 
            } else {
                showError(data.message || 'Erro desconhecido ao gerar a imagem.');
            }
        } catch (error) {
            hideElement(loadingDiv);
            console.error('Erro ao conectar ao servidor:', error);
            showError(`Não foi possível conectar ao servidor. Verifique se o backend está rodando. Detalhes: ${error.message}`);
        }
    });

    function showElement(element) {
        element.classList.remove('hidden');
    }

    function hideElement(element) {
        element.classList.add('hidden');
    }

    function showError(message) {
        errorMessageDiv.textContent = message;
        showElement(errorMessageDiv);
    }
});