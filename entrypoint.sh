#!/bin/sh
# Startskript für llama-server im Container.
#
# llama-server dient nur als API-Backend. Die eingebaute Web-Oberfläche ist
# abgeschaltet, als Oberfläche wird ausschließlich Open WebUI verwendet.
# Modelle kommen immer aus lokalen Dateien, Netzwerkzugriffe von
# llama-server sind mit --offline unterbunden.
#
# Steuerung über Umgebungsvariablen:
#   LLM_ROLE       chat | fim                         (Standard: chat)
#   LLM_MODEL      absoluter Pfad zur .gguf-Datei im Container (Pflicht)
#   LLM_ALIAS      Modellname in der API, nur chat     (Standard: local-chat)
#   LLM_PORT       Port im Container                   (Standard: 8080)
#   LLM_THREADS    CPU-Threads, ideal = physische Kerne (Standard: 4)
#   LLM_CTX        Kontextgröße in Tokens, nur chat    (Standard: 16384)
#   LLM_THINKING   0 = Denk-Modus aus, 1 = an, nur chat (Standard: 0)
#   LLM_SAMPLING   Sampling-Profil laut Model Card, nur chat (Standard: qwen)
#                  qwen        Qwen3.5 / Qwen3.6
#                  qwen-coder  Qwen3-Coder-Next
#                  gemma       Gemma 4
#                  default     Standardwerte von llama.cpp
#   LLM_EXTRA_ARGS zusätzliche llama-server-Argumente (optional)

set -eu

LLM_ROLE="${LLM_ROLE:-chat}"
LLM_MODEL="${LLM_MODEL:-}"
LLM_ALIAS="${LLM_ALIAS:-local-chat}"
LLM_PORT="${LLM_PORT:-8080}"
LLM_THREADS="${LLM_THREADS:-4}"
LLM_CTX="${LLM_CTX:-16384}"
LLM_THINKING="${LLM_THINKING:-0}"
LLM_SAMPLING="${LLM_SAMPLING:-qwen}"
LLM_EXTRA_ARGS="${LLM_EXTRA_ARGS:-}"

case "$LLM_MODEL" in
    /*) ;;
    "")
        echo "ERROR: LLM_MODEL ist nicht gesetzt" >&2
        exit 1
        ;;
    *)
        echo "ERROR: LLM_MODEL muss ein absoluter Pfad sein: $LLM_MODEL" >&2
        exit 1
        ;;
esac

if [ ! -f "$LLM_MODEL" ]; then
    echo "ERROR: Modelldatei nicht gefunden: $LLM_MODEL" >&2
    echo "       Abhilfe: ./setup.sh auf dem Host ausführen (lädt fehlende Modelle)" >&2
    exit 1
fi

# Gemeinsame Argumente: nur lokale Datei, kein Netzwerk, keine eigene Web-UI
set -- --host 0.0.0.0 --port "$LLM_PORT" --threads "$LLM_THREADS" \
       --model "$LLM_MODEL" --offline --no-webui

case "$LLM_ROLE" in
    chat)
        # Ein Slot: voller Kontext für eine einzelne Person, weniger RAM.
        # Der Alias ist der Modellname, den Open WebUI anzeigt.
        set -- "$@" --alias "$LLM_ALIAS" --ctx-size "$LLM_CTX" \
                    --parallel 1 --jinja

        # Denk-Modus über --reasoning on/off. Modelle ohne Denk-Modus
        # (Qwen3-Coder-Next) ignorieren den Wert.
        if [ "$LLM_THINKING" = "1" ]; then
            set -- "$@" --reasoning on
        else
            set -- "$@" --reasoning off
        fi

        # Sampling-Empfehlungen aus den Model Cards. Nicht genannte Werte
        # bleiben auf dem Standard von llama.cpp.
        case "$LLM_SAMPLING:$LLM_THINKING" in
            qwen:1)
                # Qwen3.5/3.6, Denk-Modus für Coding
                set -- "$@" --temp 0.6 --top-p 0.95 --top-k 20 --min-p 0
                ;;
            qwen:*)
                # Qwen3.5/3.6, Nicht-Denk-Modus
                set -- "$@" --temp 0.7 --top-p 0.8 --top-k 20 --min-p 0 \
                            --presence-penalty 1.5
                ;;
            qwen-coder:*)
                # Qwen3-Coder-Next
                set -- "$@" --temp 1.0 --top-p 0.95 --top-k 40
                ;;
            gemma:*)
                # Gemma 4, gleiche Werte mit und ohne Denk-Modus
                set -- "$@" --temp 1.0 --top-p 0.95 --top-k 64
                ;;
            default:*)
                ;;
            *)
                echo "ERROR: unbekanntes Sampling-Profil '$LLM_SAMPLING' (erlaubt: qwen, qwen-coder, gemma, default)" >&2
                exit 1
                ;;
        esac
        ;;
    fim)
        # Empfohlene CPU-Einstellungen aus dem llama.vscode-Projekt
        set -- "$@" --ctx-size 0 -ub 512 -b 512 --cache-reuse 256
        ;;
    *)
        echo "ERROR: unbekannte Rolle '$LLM_ROLE' (erlaubt: chat, fim)" >&2
        exit 1
        ;;
esac

# Zusätzliche Argumente bewusst per Wortaufteilung anhängen, ohne Globbing
if [ -n "$LLM_EXTRA_ARGS" ]; then
    set -f
    # shellcheck disable=SC2086
    set -- "$@" $LLM_EXTRA_ARGS
    set +f
fi

# Vom Basis-Image gesetzte Variablen entfernen; Host und Port kommen
# ausschließlich über die Kommandozeile (vermeidet Warnungen im Log)
unset LLAMA_ARG_HOST LLAMA_ARG_PORT

if [ "$LLM_ROLE" = "chat" ]; then
    echo "INFO: starte llama-server, Rolle=$LLM_ROLE, Modell=$LLM_MODEL, Port=$LLM_PORT, Threads=$LLM_THREADS, Kontext=$LLM_CTX, Sampling=$LLM_SAMPLING, Denk-Modus=$LLM_THINKING"
else
    echo "INFO: starte llama-server, Rolle=$LLM_ROLE, Modell=$LLM_MODEL, Port=$LLM_PORT, Threads=$LLM_THREADS"
fi
exec /app/llama-server "$@"
