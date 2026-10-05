#!/usr/bin/env python3
"""
prune_and_localize.py - Sonotype Bilingual Specialization Script
Purges non-target languages (German, French, Simplified Chinese, etc.) from VoiceInk/Localizable.xcstrings
and injects comprehensive Portuguese (pt-PT / pt-BR) translations and Sonotype branding.
"""

import json
import os
import sys

LOCALIZABLE_PATH = os.path.join(os.path.dirname(__file__), "..", "VoiceInk", "Localizable.xcstrings")

# Dictionary of English source string -> Portuguese translation
TRANSLATIONS = {
    # App Identity & Lifecycle
    "VoiceInk": "Sonotype",
    "VoiceInk Pro": "Sonotype Pro",
    "About VoiceInk": "Sobre o Sonotype",
    "Quit VoiceInk": "Encerrar o Sonotype",
    "Welcome to VoiceInk": "Bem-vindo ao Sonotype",
    "Check for Updates...": "Procurar Atualizações...",
    "Check for Updates": "Procurar Atualizações",
    "Quit": "Encerrar",
    "Settings": "Definições",
    "Preferences": "Preferências",
    "General": "Geral",
    "Help": "Ajuda",
    "System": "Sistema",
    "Light": "Claro",
    "Dark": "Escuro",
    "Version": "Versão",
    "Close": "Fechar",
    "Done": "Concluído",
    "Cancel": "Cancelar",
    "Save": "Guardar",
    "Delete": "Eliminar",
    "Edit": "Editar",
    "Add": "Adicionar",
    "Remove": "Remover",
    "Clear": "Limpar",
    "Back": "Voltar",
    "Next": "Seguinte",
    "Continue": "Continuar",
    "Skip": "Ignorar",
    "Search": "Pesquisar",
    "Filter": "Filtrar",
    "Export": "Exportar",
    "Import": "Importar",
    "Copy": "Copiar",
    "Copied!": "Copiado!",
    "Success": "Sucesso",
    "Error": "Erro",
    "Warning": "Aviso",
    "Loading...": "A carregar...",
    "Ready": "Pronto",
    "Disabled": "Desativado",
    "Enabled": "Ativado",
    "Automatic": "Automático",
    "None": "Nenhum",

    # Recording & Transcribing
    "Record": "Gravar",
    "Stop": "Parar",
    "Recording": "A gravar",
    "Recording...": "A gravar...",
    "Transcribing": "A transcrever",
    "Transcribing...": "A transcrever...",
    "Transcribed": "Transcrito",
    "Transcription": "Transcrição",
    "Transcriptions": "Transcrições",
    "Transcription History": "Histórico de Transcrições",
    "Processing": "A processar",
    "Processing...": "A processar...",
    "Enhancing": "A aprimorar",
    "Enhancing...": "A aprimorar...",
    "Hold to Record": "Manter premido para Gravar",
    "Press to Record": "Premir para Gravar",
    "Release to Stop": "Soltar para Parar",
    "Push to Talk": "Premir para Falar",
    "Hands-Free": "Mãos Livres",
    "Hands-free mode": "Modo mãos livres",
    "Audio Visualizer": "Visualizador de Áudio",
    "Microphone": "Microfone",
    "Input Device": "Dispositivo de Entrada",
    "Output Device": "Dispositivo de Saída",
    "Input Volume": "Volume de Entrada",
    "Mute": "Silenciar",
    "Unmute": "Ativar Som",
    "Listening...": "A escutar...",

    # Menu Bar & Shortcuts
    "Menu Bar": "Barra de Menus",
    "Show in Menu Bar": "Mostrar na Barra de Menus",
    "Show in Dock": "Mostrar na Dock",
    "Launch at Login": "Iniciar na Sessão",
    "Keyboard Shortcuts": "Atalhos de Teclado",
    "Record Shortcut": "Atalho de Gravação",
    "Toggle Recording": "Alternar Gravação",
    "Cancel Recording": "Cancelar Gravação",
    "Quick Switch": "Troca Rápida",
    "Press key combination": "Prima a combinação de teclas",
    "Record shortcut": "Atalho de gravação",

    # Model Library & AI
    "Models": "Modelos",
    "Model Library": "Biblioteca de Modelos",
    "Language": "Idioma",
    "Languages": "Idiomas",
    "English": "Inglês",
    "Portuguese": "Português",
    "Auto-Detect": "Deteção Automática",
    "Speed": "Velocidade",
    "Accuracy": "Precisão",
    "Size": "Tamanho",
    "Memory": "Memória",
    "Download": "Descarregar",
    "Downloading...": "A descarregar...",
    "Downloaded": "Descarregado",
    "Active": "Ativo",
    "In Use": "Em Uso",
    "Delete Model": "Eliminar Modelo",
    "On-Device": "No Dispositivo",
    "Local Models": "Modelos Locais",
    "Cloud Models": "Modelos na Nuvem",
    "Custom Models": "Modelos Personalizados",
    "Whisper Models": "Modelos Whisper",
    "Apple Speech": "Reconhecimento Apple",
    "FluidAudio": "FluidAudio",

    # AI Enhancement & Prompts
    "AI Enhancement": "Aprimoramento por IA",
    "Enhancement": "Aprimoramento",
    "Prompts": "Prompts",
    "Prompt Templates": "Modelos de Prompt",
    "Custom Prompt": "Prompt Personalizado",
    "Custom Prompts": "Prompts Personalizados",
    "System Prompt": "Prompt de Sistema",
    "API Key": "Chave de API",
    "Provider": "Fornecedor",
    "Clean up transcript": "Limpar transcrição",
    "Remove filler words": "Remover palavras de hesitação",
    "Fix grammar and punctuation": "Corrigir gramática e pontuação",
    "Summarize": "Resumir",
    "Summary": "Resumo",
    "Bullet points": "Pontos principais",
    "Translate to English": "Traduzir para Inglês",
    "Translate to Portuguese": "Traduzir para Português",
    "Vocabulary": "Vocabulário",
    "Custom Vocabulary": "Vocabulário Personalizado",
    "Word Replacements": "Substituição de Palavras",
    "Add Word": "Adicionar Palavra",
    "Replace": "Substituir",
    "With": "Por",
    "Original": "Original",

    # History & Export
    "History": "Histórico",
    "No transcriptions yet": "Ainda sem transcrições",
    "No Transcriptions": "Sem Transcrições",
    "Search transcriptions...": "Pesquisar transcrições...",
    "Copy Text": "Copiar Texto",
    "Play Audio": "Reproduzir Áudio",
    "Pause Audio": "Pausar Áudio",
    "Export as CSV": "Exportar como CSV",
    "Delete Selected": "Eliminar Selecionados",
    "Delete All": "Eliminar Tudo",
    "Confirm Deletion": "Confirmar Eliminação",
    "Are you sure you want to delete this?": "Tem a certeza de que pretende eliminar?",

    # Audio Import
    "Transcribe Audio": "Transcrever Áudio",
    "Import Audio File": "Importar Ficheiro de Áudio",
    "Drag & drop audio files here": "Arraste e largue ficheiros de áudio aqui",
    "Choose File": "Escolher Ficheiro",
    "Supported formats: WAV, MP3, M4A, AAC": "Formatos suportados: WAV, MP3, M4A, AAC",

    # Onboarding
    "Get Started": "Começar",
    "Microphone Permission": "Permissão do Microfone",
    "Accessibility Permission": "Permissão de Acessibilidade",
    "Grant Permission": "Conceder Permissão",
    "Permissions": "Permissões",
    "Welcome to Sonotype!": "Bem-vindo ao Sonotype!",
    "Your private, offline voice-to-text companion.": "O seu assistente privado e offline de voz para texto.",
    "Choose your preferred shortcut to start speaking.": "Escolha o seu atalho preferido para começar a falar.",

    # Feedback & Licensing
    "License": "Licença",
    "Active License": "Licença Ativa",
    "Lifetime Access": "Acesso Vitalício",
    "Pro Features": "Funcionalidades Pro",
    "Feedback": "Feedback",
    "Sound Effects": "Efeitos Sonoros",
    "Play sound on record start": "Tocar som ao iniciar gravação",
    "Play sound on record stop": "Tocar som ao parar gravação",
}

def clean_and_localize():
    path = os.path.abspath(LOCALIZABLE_PATH)
    if not os.path.exists(path):
        print(f"Error: Could not find {path}")
        sys.exit(1)

    print(f"Loading {path}...")
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    strings = data.get("strings", {})
    initial_count = len(strings)
    print(f"Found {initial_count} string entries.")

    purged_languages = {"de", "fr", "zh-Hans", "es", "it", "ja", "ko", "ru"}
    kept_languages = {"en", "pt", "pt-PT", "pt-BR"}

    purged_lang_count = 0
    translated_count = 0

    for key, entry in strings.items():
        # Clean localizations
        if "localizations" in entry:
            locs = entry["localizations"]
            for lang in list(locs.keys()):
                if lang in purged_languages or (lang not in kept_languages):
                    del locs[lang]
                    purged_lang_count += 1

        # Check if we should translate to Portuguese
        pt_val = TRANSLATIONS.get(key)
        if not pt_val:
            # Rebrand check
            if "VoiceInk" in key:
                pt_val = key.replace("VoiceInk", "Sonotype")
            # Case insensitive exact lookup
            for k, v in TRANSLATIONS.items():
                if k.lower() == key.lower():
                    pt_val = v
                    break

        if pt_val:
            if "localizations" not in entry:
                entry["localizations"] = {}
            locs = entry["localizations"]

            # Set pt, pt-PT, pt-BR
            for pt_key in ["pt", "pt-PT", "pt-BR"]:
                locs[pt_key] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": pt_val
                    }
                }
            translated_count += 1

    # Ensure sourceLanguage is en
    data["sourceLanguage"] = "en"

    # Write back clean JSON
    print("Writing optimized strings file...")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    new_size = os.path.getsize(path)
    print(f"Done! Cleaned {purged_lang_count} dead language blocks.")
    print(f"Injected {translated_count} Portuguese translations.")
    print(f"New file size: {new_size / 1024:.1f} KB")

if __name__ == "__main__":
    clean_and_localize()
