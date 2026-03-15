{ config, pkgs, lib, ... }:

{
  # Local AI bundle with Intel Arc A770 GPU acceleration via IPEX-LLM
  # Architecture:
  #   - IPEX-LLM Ollama (Docker): GPU-accelerated inference on Intel Arc
  #   - Open WebUI: ChatGPT-like web interface
  #   - LiteLLM: Unified OpenAI-compatible API

  # Disable system Ollama - we use the IPEX-LLM Docker version instead
  # services.ollama.enable = false;

  # Docker containers for AI stack
  virtualisation.docker.enable = true;
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      # IPEX-LLM Ollama with Intel Arc GPU acceleration
      ipex-ollama = {
        image = "intelanalytics/ipex-llm-inference-cpp-xpu:latest";
        autoStart = true;
        volumes = [
          "ollama-models:/root/.ollama"
        ];
        environment = {
          DEVICE = "Arc";
          OLLAMA_HOST = "0.0.0.0:11434";
          OLLAMA_NUM_PARALLEL = "2";
          OLLAMA_MAX_LOADED_MODELS = "1";
          # Use only the Arc A770 (device 0), not the integrated GPU
          ONEAPI_DEVICE_SELECTOR = "level_zero:0";
          # Performance tuning for Arc
          SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS = "1";
          # Enable memory info
          ZES_ENABLE_SYSMAN = "1";
        };
        extraOptions = [
          "--device=/dev/dri"
          "--network=host"
          "--shm-size=16g"
          "--privileged"  # Needed for GPU access
        ];
        # The container has its own entrypoint that sets up oneAPI
        cmd = [ "bash" "-c" "cd /llm/scripts && ./start-ollama.sh; sleep infinity" ];
      };

      # Open WebUI - ChatGPT-like interface
      open-webui = {
        image = "ghcr.io/open-webui/open-webui:main";
        autoStart = true;
        volumes = [
          "open-webui:/app/backend/data"
        ];
        dependsOn = [ "ipex-ollama" ];
        extraOptions = [
          "--network=host"  # Use host networking to reach Ollama
        ];
        environment = {
          PORT = "3000";  # Run on port 3000 since we're using host networking
          OLLAMA_BASE_URL = "http://127.0.0.1:11434";
          OPENAI_API_BASE_URLS = "http://127.0.0.1:4000/v1";
          ENABLE_OPENAI_API = "true";
          ENABLE_MODEL_FILTER = "false";
          # Disable authentication (for home/local use only)
          #WEBUI_AUTH = "false";
          # Web search via SearXNG
          ENABLE_RAG_WEB_SEARCH = "true";
          RAG_WEB_SEARCH_ENGINE = "searxng";
          SEARXNG_QUERY_URL = "http://127.0.0.1:8080/search?q=<query>&format=json";
          # Audio: Use Speaches for TTS (OpenAI-compatible)
          AUDIO_TTS_ENGINE = "openai";
          AUDIO_TTS_OPENAI_API_BASE_URL = "http://127.0.0.1:8000/v1";
          AUDIO_TTS_OPENAI_API_KEY = "not-needed";
          AUDIO_TTS_MODEL = "speaches-ai/Kokoro-82M-v1.0-ONNX";  # Full model ID required
          AUDIO_TTS_VOICE = "af_heart";  # Kokoro voice (natural female)
          # Audio: Use Speaches for STT (OpenAI-compatible)
          AUDIO_STT_ENGINE = "openai";
          AUDIO_STT_OPENAI_API_BASE_URL = "http://127.0.0.1:8000/v1";
          AUDIO_STT_OPENAI_API_KEY = "not-needed";
          AUDIO_STT_MODEL = "Systran/faster-whisper-small.en";  # Full model ID required
        };
      };

      # LiteLLM proxy - OpenAI-compatible API aggregator
      litellm-proxy = {
        image = "ghcr.io/berriai/litellm:main-latest";
        autoStart = true;
        volumes = [
          "/var/lib/litellm:/app/config"
        ];
        dependsOn = [ "ipex-ollama" ];
        extraOptions = [
          "--network=host"  # Use host networking to reach Ollama
        ];
        environment = {
          LITELLM_MASTER_KEY = "sk-local-ai-key";
          PORT = "4000";
        };
        cmd = [ "--config" "/app/config/config.yaml" "--port" "4000" ];
      };

      # Speaches - Combined TTS + STT server (OpenAI-compatible)
      # Includes Piper TTS, Kokoro TTS (#1 ranked), and Faster-Whisper STT
      # Access at: http://localhost:8000
      # Note: CPU-only for now - Whisper has no Intel GPU support in Docker yet
      # Piper TTS is designed for CPU and is very fast anyway
      speaches = {
        image = "ghcr.io/speaches-ai/speaches:latest-cpu";
        autoStart = true;
        volumes = [
          "speaches-cache:/home/ubuntu/.cache/huggingface/hub"
        ];
        extraOptions = [
          "--network=host"
        ];
        environment = {
          # Use environment variables for config (double underscore for nested)
          UVICORN_HOST = "0.0.0.0";
          UVICORN_PORT = "8000";
          # Connect to local Ollama for voice chat mode
          CHAT_COMPLETION_BASE_URL = "http://127.0.0.1:11434/v1";
          # Model settings - keep models loaded to avoid cold start delays
          STT_MODEL_TTL = "-1";  # Never unload STT model
          TTS_MODEL_TTL = "-1";  # Never unload TTS model
          # Enable VAD for better transcription
          _UNSTABLE_VAD_FILTER = "true";
          LOG_LEVEL = "info";
          # Preload Kokoro TTS and Whisper STT models
          PRELOAD_MODELS = ''["speaches-ai/Kokoro-82M-v1.0-ONNX", "Systran/faster-whisper-base.en", "Systran/faster-whisper-small.en"]'';
        };
      };

      # SearXNG - Self-hosted meta-search engine for web search
      # Access at: http://localhost:8080
      searxng = {
        image = "searxng/searxng:latest";
        autoStart = true;
        volumes = [
          "/var/lib/searxng/settings.yml:/etc/searxng/settings.yml:ro"
        ];
        extraOptions = [
          "--network=host"
        ];
        environment = {
          SEARXNG_BASE_URL = "http://localhost:8080";
        };
      };

      # Spleeter - Audio source separation (music/vocals)
      # Access via command line or wrapper script
      spleeter = {
        image = "researchdeezer/spleeter:latest";
        autoStart = false;  # Start manually with: systemctl start docker-spleeter
        volumes = [
          "/:/hostfs:ro"
          "/cloud/Entertainment/Music/Production/Split:/output"
          "spleeter-models:/model"
        ];
        environment = {
          MODEL_PATH = "/model";
        };
        extraOptions = [
          "--network=host"
          "-e" "PYTHONUNBUFFERED=1"
          "--entrypoint" "sh"
        ];
        cmd = [ "-c" "sleep infinity" ];
      };
    };
  };

  # Intel Arc GPU compute stack
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-compute-runtime
      intel-media-driver
      vpl-gpu-rt
      level-zero
      intel-gmmlib
      openvino
    ];
  };

  # Ensure render group exists
  users.groups.render = {};

  # System packages and helper tools
  environment.systemPackages = with pkgs; [
    intel-gpu-tools  # Provides intel_gpu_top
    nvtopPackages.intel  # Alternative GPU monitor
    clinfo
    vulkan-tools

    # Main setup script
    (writeShellScriptBin "ai-setup" ''
      #!/usr/bin/env bash
      echo "🤖 Intel Arc Local AI Setup (IPEX-LLM Docker)"
      echo "=============================================="
      echo ""
      
      # Create directories
      sudo mkdir -p /var/lib/litellm
      sudo chown -R $USER:users /var/lib/litellm
      
      # Create LiteLLM config
      cat > /var/lib/litellm/config.yaml << 'EOF'
model_list:
  # Ollama models via IPEX-LLM (GPU accelerated)
  - model_name: "ollama/*"
    litellm_params:
      model: "ollama/*"
      api_base: http://127.0.0.1:11434

  # Common model aliases
  - model_name: llama3.2:3b
    litellm_params:
      model: ollama/llama3.2:3b
      api_base: http://127.0.0.1:11434

  - model_name: llama3.2
    litellm_params:
      model: ollama/llama3.2
      api_base: http://127.0.0.1:11434
      
  - model_name: deepseek-r1:7b
    litellm_params:
      model: ollama/deepseek-r1:7b
      api_base: http://127.0.0.1:11434

  - model_name: codellama
    litellm_params:
      model: ollama/codellama
      api_base: http://127.0.0.1:11434

  - model_name: qwen2.5-coder
    litellm_params:
      model: ollama/qwen2.5-coder
      api_base: http://127.0.0.1:11434

general_settings:
  master_key: sk-local-ai-key
EOF

      echo "✅ Configuration created!"
      echo ""
      echo "🌐 Access Points:"
      echo "  Web UI:      http://localhost:3000"
      echo "  Ollama API:  http://localhost:11434 (GPU accelerated!)"
      echo "  OpenAI API:  http://localhost:4000/v1"
      echo ""
      echo "📚 Quick Start:"
      echo "  1. Pull a model:  ai-pull llama3.2:3b"
      echo "  2. Check status:  ai-status"
      echo "  3. Open Web UI:   firefox http://localhost:3000"
      echo "  4. See models:    ai-models"
    '')

    # Pull model via Docker (since ollama CLI isn't installed on host)
    (writeShellScriptBin "ai-pull" ''
      #!/usr/bin/env bash
      if [ -z "$1" ]; then
        echo "Usage: ai-pull <model-name>"
        echo "Example: ai-pull llama3.2:3b"
        echo ""
        echo "Run 'ai-models' for recommended models"
        exit 1
      fi
      
      echo "📥 Pulling model: $1"
      echo ""
      docker exec -it ipex-ollama /llm/ollama/ollama pull "$1"
    '')

    # Run model interactively via Docker
    (writeShellScriptBin "ai-run" ''
      #!/usr/bin/env bash
      if [ -z "$1" ]; then
        echo "Usage: ai-run <model-name>"
        echo "Example: ai-run llama3.2:3b"
        exit 1
      fi
      
      echo "🤖 Running model: $1 (Intel Arc GPU)"
      echo "Type 'exit' or Ctrl+D to quit"
      echo ""
      docker exec -it ipex-ollama /llm/ollama/ollama run "$1"
    '')

    # List models via Docker
    (writeShellScriptBin "ai-list" ''
      #!/usr/bin/env bash
      echo "📋 Installed Models:"
      docker exec ipex-ollama /llm/ollama/ollama list
    '')

    # Model recommendations for Arc A770
    (writeShellScriptBin "ai-models" ''
      #!/usr/bin/env bash
      echo "🤖 Recommended Models for Intel Arc A770 (16GB VRAM)"
      echo "===================================================="
      echo ""
      echo "📊 Model Sizes & Performance:"
      echo ""
      echo "🟢 SMALL (Fast, <8GB VRAM):"
      echo "  ai-pull llama3.2:3b         # General purpose, very fast"
      echo "  ai-pull phi4                # Microsoft, efficient"
      echo "  ai-pull qwen2.5-coder:3b    # Coding focused"
      echo "  ai-pull gemma2:2b           # Google, compact"
      echo ""
      echo "🟡 MEDIUM (Balanced, 8-14GB VRAM):"
      echo "  ai-pull deepseek-r1:7b      # Reasoning model (recommended!)"
      echo "  ai-pull llama3.2:7b         # Better quality"
      echo "  ai-pull codellama:7b        # Code generation"
      echo "  ai-pull mistral:7b          # Fast & capable"
      echo "  ai-pull qwen2.5:7b          # Multilingual"
      echo ""
      echo "🔴 LARGE (Best quality, 14-16GB VRAM):"
      echo "  ai-pull llama3.2:13b        # High quality"
      echo "  ai-pull codellama:13b       # Best for code"
      echo ""
      echo "💡 Tips:"
      echo "  • Start with 3b/7b models to test GPU acceleration"
      echo "  • Run 'ai-test-gpu' while chatting to see GPU usage"
      echo "  • Use 'ai-run <model>' for CLI chat"
      echo "  • Or open http://localhost:3000 for web UI"
    '')

    # Status check script
    (writeShellScriptBin "ai-status" ''
      #!/usr/bin/env bash
      echo "🔍 AI Stack Status"
      echo "=================="
      echo ""
      
      # Check IPEX-Ollama container
      if docker ps --format '{{.Names}}' | grep -q "ipex-ollama"; then
        echo "✅ IPEX-Ollama: Running (Intel Arc GPU)"
        if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
          echo "   API: http://localhost:11434 ✅"
          MODELS=$(docker exec ipex-ollama /llm/ollama/ollama list 2>/dev/null | tail -n +2)
          if [ -n "$MODELS" ]; then
            echo "   Models:"
            echo "$MODELS" | while read line; do echo "     $line"; done
          else
            echo "   ⚠️  No models installed (run: ai-pull llama3.2:3b)"
          fi
        else
          echo "   API: Starting up... (wait a moment)"
        fi
      else
        echo "❌ IPEX-Ollama: Not running"
        echo "   Try: sudo systemctl start docker-ipex-ollama"
      fi
      echo ""
      
      # Check Open WebUI
      if curl -s http://localhost:3000 >/dev/null 2>&1; then
        echo "✅ Web UI:      Running (http://localhost:3000)"
      else
        echo "❌ Web UI:      Not responding"
        echo "   Try: sudo systemctl start docker-open-webui"
      fi
      echo ""
      
      # Check LiteLLM
      if curl -s http://localhost:4000/health >/dev/null 2>&1; then
        echo "✅ LiteLLM:     Running (http://localhost:4000)"
      else
        echo "⚠️  LiteLLM:     Not responding"
        echo "   Try: sudo systemctl start docker-litellm-proxy"
      fi
      echo ""
      
      # GPU Info
      echo "🎮 Intel GPU:"
      if [ -e /dev/dri/renderD128 ]; then
        echo "   Render device: /dev/dri/renderD128 ✅"
        clinfo -l 2>/dev/null | grep -i "Arc\|intel" | head -3 | while read line; do echo "   $line"; done
      else
        echo "   ⚠️  No render device found"
      fi
    '')

    # GPU test script
    (writeShellScriptBin "ai-test-gpu" ''
      #!/usr/bin/env bash
      echo "🧪 Intel GPU Test"
      echo "================="
      echo ""
      
      echo "📊 GPU Devices:"
      ls -la /dev/dri/ 2>/dev/null
      echo ""
      
      echo "🔧 OpenCL Platforms:"
      clinfo -l 2>/dev/null || echo "clinfo not available"
      echo ""
      
      echo "📈 GPU Activity:"
      echo "(requires sudo - press Ctrl+C to stop)"
      sudo intel_gpu_top -l 2>/dev/null || nvtop 2>/dev/null || echo "GPU monitoring not available"
    '')

    # API test script
    (writeShellScriptBin "ai-test-api" ''
      #!/usr/bin/env bash
      echo "🧪 Testing AI APIs"
      echo "=================="
      echo ""
      
      MODEL=''${1:-llama3.2:3b}
      
      echo "📡 Testing Ollama API with $MODEL..."
      RESPONSE=$(curl -s http://localhost:11434/api/generate -d "{
        \"model\": \"$MODEL\",
        \"prompt\": \"Say hello in one sentence.\",
        \"stream\": false
      }" 2>&1)
      
      if echo "$RESPONSE" | grep -q "response"; then
        echo "✅ Ollama API working!"
        echo "Response: $(echo "$RESPONSE" | grep -o '"response":"[^"]*"' | head -1)"
      else
        echo "❌ Ollama API error: $RESPONSE"
      fi
      echo ""
      
      echo "📡 Testing OpenAI-compatible API (LiteLLM)..."
      RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
        -H "Authorization: Bearer sk-local-ai-key" \
        -H "Content-Type: application/json" \
        -d "{
          \"model\": \"$MODEL\",
          \"messages\": [{\"role\": \"user\", \"content\": \"Say hello briefly.\"}]
        }" 2>&1)
      
      if echo "$RESPONSE" | grep -q "choices"; then
        echo "✅ OpenAI API working!"
      else
        echo "⚠️  OpenAI API: $RESPONSE"
      fi
    '')

    # View IPEX-Ollama logs
    (writeShellScriptBin "ai-logs" ''
      #!/usr/bin/env bash
      echo "📜 IPEX-Ollama Container Logs"
      echo "============================="
      docker logs -f ipex-ollama
    '')

    # Restart AI stack
    (writeShellScriptBin "ai-restart" ''
      #!/usr/bin/env bash
      echo "🔄 Restarting AI Stack..."
      sudo systemctl restart docker-ipex-ollama
      sleep 5
      sudo systemctl restart docker-open-webui
      sudo systemctl restart docker-litellm-proxy
      echo "✅ Done! Run 'ai-status' to check."
    '')

    # Voice chat status
    (writeShellScriptBin "ai-voice-status" ''
      #!/usr/bin/env bash
      echo "🎤 Voice Chat Status (Speaches)"
      echo "================================"
      echo ""
      
      # Check Speaches
      if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        echo "✅ Speaches:  Running (http://localhost:8000)"
        echo ""
        
        # Check loaded models
        MODELS=$(curl -s http://localhost:8000/v1/models 2>&1)
        if echo "$MODELS" | grep -q "Kokoro"; then
          echo "   TTS Model: speaches-ai/Kokoro-82M-v1.0-ONNX ✅"
        else
          echo "   TTS Model: Not loaded ⚠️  (run: ai-voice-setup)"
        fi
        if echo "$MODELS" | grep -q "whisper"; then
          echo "   STT Model: Systran/faster-whisper-small.en ✅"
        else
          echo "   STT Model: Not loaded ⚠️  (run: ai-voice-setup)"
        fi
        echo ""
        echo "   WebUI: http://localhost:8000 (built-in test interface)"
      elif docker ps --format '{{.Names}}' | grep -q "speaches"; then
        echo "⏳ Speaches:  Starting up..."
        echo "   Check progress: ai-voice-logs"
      else
        echo "❌ Speaches:  Not running"
        echo "   Try: sudo systemctl start docker-speaches"
      fi
      echo ""
      
      echo "💡 Usage:"
      echo "   1. Run: ai-voice-setup (first time, downloads models)"
      echo "   2. Open http://localhost:3000"
      echo "   3. Click the microphone icon to speak"
      echo "   4. AI will respond with voice!"
      echo ""
      echo "🎭 Voice Options (change in Open WebUI Settings → Audio):"
      echo "   Kokoro voices: af_heart, af_bella, am_adam, am_michael"
      echo ""
      echo "⚠️  Note: Voice runs on CPU (no Intel GPU Whisper support yet)"
      echo "   Kokoro TTS is very fast and high quality on CPU"
    '')

    # Setup voice models (download on first use)
    (writeShellScriptBin "ai-voice-setup" ''
      #!/usr/bin/env bash
      echo "🎤 Setting up Voice Models (Speaches)"
      echo "======================================"
      echo ""
      
      if ! curl -s http://localhost:8000/health >/dev/null 2>&1; then
        echo "❌ Speaches not running! Start it first:"
        echo "   sudo systemctl start docker-speaches"
        exit 1
      fi
      
      echo "📥 Downloading Kokoro TTS model (~180MB)..."
      curl -X POST "http://localhost:8000/v1/models/speaches-ai%2FKokoro-82M-v1.0-ONNX"
      echo ""
      
      echo "📥 Downloading Whisper STT model (~500MB)..."
      curl -X POST "http://localhost:8000/v1/models/Systran%2Ffaster-whisper-small.en"
      echo ""
      
      echo "✅ Voice models installed!"
      echo ""
      echo "Test with: ai-voice-test"
      echo "Or open: http://localhost:3000"
    '')

    # Test TTS
    (writeShellScriptBin "ai-voice-test" ''
      #!/usr/bin/env bash
      echo "🧪 Testing Voice Services (Speaches)"
      echo "====================================="
      echo ""
      
      # First check if models are loaded
      MODELS=$(curl -s http://localhost:8000/v1/models 2>&1)
      if echo "$MODELS" | grep -q '"data":\[\]'; then
        echo "⚠️  No models loaded! Downloading required models..."
        echo ""
        echo "📥 Downloading Kokoro TTS model..."
        curl -s -X POST "http://localhost:8000/v1/models/speaches-ai%2FKokoro-82M-v1.0-ONNX" >/dev/null 2>&1
        echo "📥 Downloading Whisper STT model..."
        curl -s -X POST "http://localhost:8000/v1/models/Systran%2Ffaster-whisper-small.en" >/dev/null 2>&1
        echo "✅ Models downloaded!"
        echo ""
      fi
      
      echo "📢 Testing Text-to-Speech (Kokoro)..."
      RESPONSE=$(curl -s -X POST http://localhost:8000/v1/audio/speech \
        -H "Content-Type: application/json" \
        -d '{"model": "speaches-ai/Kokoro-82M-v1.0-ONNX", "voice": "af_heart", "input": "Hello! Voice chat is working great."}' \
        --output /tmp/test-tts.mp3 -w "%{http_code}" 2>&1)
      
      if [ "$RESPONSE" = "200" ] && [ -s /tmp/test-tts.mp3 ]; then
        echo "✅ TTS working! Playing audio..."
        ${pkgs.mpv}/bin/mpv --no-video /tmp/test-tts.mp3 2>/dev/null || \
          echo "   Audio saved to /tmp/test-tts.mp3 (install mpv to play)"
      else
        echo "❌ TTS error (HTTP $RESPONSE)"
        echo "   Check: ai-voice-logs"
      fi
      echo ""
      
      echo "🎤 Testing Speech-to-Text (Whisper)..."
      if [ -f /tmp/test-tts.mp3 ]; then
        RESPONSE=$(curl -s -X POST http://localhost:8000/v1/audio/transcriptions \
          -F "file=@/tmp/test-tts.mp3" \
          -F "model=Systran/faster-whisper-small.en" 2>&1)
        
        if echo "$RESPONSE" | grep -q "text"; then
          echo "✅ STT working!"
          echo "   Transcribed: $(echo "$RESPONSE" | grep -o '"text":"[^"]*"' | sed 's/"text":"//;s/"$//')"
        else
          echo "⚠️  STT response: $RESPONSE"
        fi
      else
        echo "⚠️  No test audio file (TTS must work first)"
      fi
      echo ""
      
      echo "🎙️  Voice chat ready! Open http://localhost:3000"
    '')

    # Voice logs
    (writeShellScriptBin "ai-voice-logs" ''
      #!/usr/bin/env bash
      echo "📜 Speaches Logs"
      echo "================"
      docker logs -f speaches
    '')

    # Restart voice services
    (writeShellScriptBin "ai-voice-restart" ''
      #!/usr/bin/env bash
      echo "🔄 Restarting Speaches..."
      sudo systemctl restart docker-speaches
      echo "✅ Done! Run 'ai-voice-status' to check."
    '')

    # Spleeter container management info
    (writeShellScriptBin "spleeter-info" ''
      #!/usr/bin/env bash
      echo "🎵 Spleeter Container Management"
      echo "================================="
      echo ""
      echo "Start:    systemctl start docker-spleeter"
      echo "Stop:     systemctl stop docker-spleeter"
      echo "Status:   systemctl status docker-spleeter"
      echo "Logs:     journalctl -u docker-spleeter -f"
      echo ""
      echo "Current status:"
      systemctl is-active docker-spleeter && echo "  ✅ Running" || echo "  ❌ Not running"
    '')

    # Spleeter - Audio source separation (music/vocals)
    (writeShellScriptBin "spleeter" ''
      #!/usr/bin/env bash
      
      # Show help if no args
      if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "🎵 Spleeter - Audio Source Separation"
        echo "======================================"
        echo ""
        echo "Separate audio into stems (vocals, drums, bass, etc.)"
        echo ""
        echo "Setup (first time only):"
        echo "  systemctl start docker-spleeter"
        echo ""
        echo "Usage:"
        echo "  spleeter <audio_file> [OPTIONS]"
        echo ""
        echo "Examples:"
        echo "  # 4 stems (vocals, drums, bass, other) - default"
        echo "  spleeter ~/Music/song.mp3"
        echo "  spleeter /arbitrary/path/to/song.mp3"
        echo ""
        echo "  # 5 stems (vocals, drums, bass, piano, other)"
        echo "  spleeter ~/Music/song.mp3 -piano"
        echo ""
        echo "Management:"
        echo "  spleeter-info            # Show container status and commands"
        echo ""
        echo "Output:"
        echo "  /cloud/Entertainment/Music/Production/Split/song/"
        echo "    ├── vocals.wav"
        echo "    ├── drums.wav"
        echo "    ├── bass.wav"
        echo "    └── other.wav"
        echo ""
        exit 0
      fi
      
      # Check if container is running
      if ! docker ps --format '{{.Names}}' | grep -q "^spleeter$"; then
        echo "❌ Spleeter container not running"
        echo ""
        echo "Start it with: systemctl start docker-spleeter"
        exit 1
      fi
      
      AUDIO_FILE="$1"
      USE_PIANO=false
      
      # Check for -piano flag
      if [ "$2" = "-piano" ]; then
        USE_PIANO=true
        STEM_MODEL="spleeter:5stems"
      else
        STEM_MODEL="spleeter:4stems"
      fi
      
      if [ -z "$AUDIO_FILE" ]; then
        echo "❌ No audio file specified"
        exit 1
      fi
      
      # Resolve absolute path
      if [[ "$AUDIO_FILE" == ~* ]]; then
        AUDIO_FILE="''${AUDIO_FILE/#\~/$HOME}"
      fi
      
      if [ ! -f "$AUDIO_FILE" ]; then
        echo "❌ Audio file not found: $AUDIO_FILE"
        exit 1
      fi
      
      # Get absolute path and filename info
      AUDIO_FILE=$(cd "$(dirname "$AUDIO_FILE")" && pwd)/$(basename "$AUDIO_FILE")
      FILENAME=$(basename "$AUDIO_FILE")
      FILENAME_NOEXT="''${FILENAME%.*}"
      
      # Map the input file path: /actual/path/file.mp3 -> /hostfs/actual/path/file.mp3
      CONTAINER_AUDIO_PATH="/hostfs$AUDIO_FILE"
      
      # Set up output path
      OUTPUT_BASE="/home/adam/spleeter/output"
      FINAL_OUTPUT_DIR="$OUTPUT_BASE/''${FILENAME_NOEXT}"
      
      echo "🎵 Spleeting: $FILENAME"
      echo "Mode: $([ "$USE_PIANO" = true ] && echo "5 stems (with piano)" || echo "4 stems")"
      echo "Output: $FINAL_OUTPUT_DIR"
      echo ""
      
      # Clean up existing output directory (let container handle it to avoid permission issues)
      docker exec spleeter sh -c "rm -rf /output/''${FILENAME_NOEXT}"
      
      # Run spleeter in the persistent container via docker exec
      docker exec spleeter \
        spleeter separate \
        -p "$STEM_MODEL" \
        -i "$CONTAINER_AUDIO_PATH" \
        -o /output
      
      if [ $? -ne 0 ]; then
        echo "❌ Separation failed"
        exit 1
      fi
      
      echo ""
      echo "✅ Separation complete!"
      echo "📁 Output directory: $FINAL_OUTPUT_DIR"
      echo ""
      echo "📋 Files:"
      ls -lh "$FINAL_OUTPUT_DIR" | tail -n +2 | awk '{printf "   %-15s %8s\n", $9, $5}'
    '')
  ];

  # Firewall configuration
  networking.firewall.allowedTCPPorts = [
    11434  # Ollama API
    3000   # Open WebUI
    4000   # LiteLLM (OpenAI-compatible)
    8000   # Speaches TTS/STT API
    8080   # SearXNG web search
  ];

  # GPU permissions setup service
  systemd.services.ai-gpu-setup = {
    description = "Setup Intel GPU for AI workloads";
    before = [ "docker-ipex-ollama.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.coreutils}/bin/chmod 666 /dev/dri/renderD* 2>/dev/null || true
      ${pkgs.coreutils}/bin/chmod 666 /dev/dri/card* 2>/dev/null || true
      echo "Intel GPU permissions configured"
    '';
  };

  # System optimizations for AI
  boot.kernel.sysctl = {
    "kernel.shmmax" = 68719476736;
    "kernel.shmall" = 4294967296;
  };
}
