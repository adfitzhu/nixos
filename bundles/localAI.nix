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
          WEBUI_AUTH = "false";
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

      # Stable Diffusion WebUI with OpenVINO for Intel Arc GPU
      # Access at: http://localhost:7860
      stable-diffusion = {
        image = "ghcr.io/openvino-dev-samples/stable_diffusion.openvino:latest";
        autoStart = false;  # Start manually: sudo systemctl start docker-stable-diffusion
        volumes = [
          "sd-models:/sd/models"
          "sd-outputs:/sd/outputs"
        ];
        environment = {
          DEVICE = "GPU";
        };
        extraOptions = [
          "--device=/dev/dri"
          "--network=host"
          "--shm-size=8g"
          "--privileged"
        ];
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

    # Image generation commands
    (writeShellScriptBin "ai-image-start" ''
      #!/usr/bin/env bash
      echo "🎨 Starting Stable Diffusion (Intel Arc GPU)"
      echo "============================================="
      echo ""
      echo "Starting container (first run will download ~10GB of models)..."
      sudo systemctl start docker-stable-diffusion
      
      echo ""
      echo "Waiting for WebUI to start..."
      for i in {1..60}; do
        if curl -s http://localhost:7860 >/dev/null 2>&1; then
          echo ""
          echo "✅ Stable Diffusion WebUI is ready!"
          echo "🌐 Open: http://localhost:7860"
          exit 0
        fi
        echo -n "."
        sleep 2
      done
      
      echo ""
      echo "⚠️  WebUI not responding yet. Check logs with: ai-image-logs"
    '')

    (writeShellScriptBin "ai-image-stop" ''
      #!/usr/bin/env bash
      echo "🛑 Stopping Stable Diffusion..."
      sudo systemctl stop docker-stable-diffusion
      echo "✅ Stopped"
    '')

    (writeShellScriptBin "ai-image-logs" ''
      #!/usr/bin/env bash
      echo "📜 Stable Diffusion Container Logs"
      docker logs -f stable-diffusion
    '')

    (writeShellScriptBin "ai-image-info" ''
      #!/usr/bin/env bash
      echo "🎨 Image Generation on Intel Arc A770"
      echo "======================================"
      echo ""
      echo "📦 Stable Diffusion WebUI (OpenVINO)"
      echo "   Status: $(systemctl is-active docker-stable-diffusion 2>/dev/null || echo 'not configured')"
      echo "   URL: http://localhost:7860"
      echo "   Start: ai-image-start"
      echo "   Stop:  ai-image-stop"
      echo ""
      echo "🚀 Quick Start:"
      echo "   1. Run: ai-image-start"
      echo "   2. Wait for download/startup (~5-10 min first time)"
      echo "   3. Open: http://localhost:7860"
      echo ""
      echo "💡 Features:"
      echo "   • Text-to-Image generation"
      echo "   • Image-to-Image transformation"
      echo "   • Inpainting"
      echo "   • Uses Intel Arc GPU via OpenVINO"
      echo ""
      echo "📁 Data stored in Docker volumes:"
      echo "   • Models: sd-models"
      echo "   • Outputs: sd-outputs"
    '')
  ];

  # Firewall configuration
  networking.firewall.allowedTCPPorts = [
    11434  # Ollama API
    3000   # Open WebUI
    4000   # LiteLLM (OpenAI-compatible)
    7860   # Stable Diffusion WebUI
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
