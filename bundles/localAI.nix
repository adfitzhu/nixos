{ config, pkgs, lib, ... }:

{
  # Local AI bundle with Ollama and Intel Arc A770 GPU acceleration
  # Provides: Ollama LLM server, web UI, and necessary GPU support

  # Enable Ollama service
  services.ollama = {
    enable = true;
    acceleration = null; # Use CPU/integrated GPU - Intel Arc not supported
    # Listen on all interfaces to allow Android/remote access
    host = "0.0.0.0";
    port = 11434;
    # Store models in a dedicated location
    home = "/var/lib/ollama";
    # Use CPU with optimizations
    environmentVariables = {
      # Set number of parallel requests
      OLLAMA_NUM_PARALLEL = "4";
      # Max loaded models
      OLLAMA_MAX_LOADED_MODELS = "2";
    };
  };

  # Install Ollama Web UI (formerly Ollama WebUI, now Open WebUI)
  virtualisation.docker.enable = true;
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      open-webui = {
        image = "ghcr.io/open-webui/open-webui:main";
        autoStart = true;
        volumes = [
          "open-webui:/app/backend/data"
        ];
        extraOptions = [
          "--add-host=host.docker.internal:host-gateway"
          "--network=host"
        ];
        environment = {
          # Primary backend - Ollama
          OLLAMA_BASE_URL = "http://127.0.0.1:11434";
          # Additional OpenAI-compatible backends
          OPENAI_API_BASE_URLS = "http://127.0.0.1:4000/v1";  # LiteLLM proxy for OpenVINO
          ENABLE_OPENAI_API = "true";
          # Allow multiple model sources
          ENABLE_MODEL_FILTER = "false";
        };
      };

      # Intel OpenVINO Model Server for Intel GPU acceleration
      openvino-model-server = {
        image = "openvino/model_server:latest";
        autoStart = false; # Start manually when needed
        ports = [
          "9000:9000"  # gRPC API
          "8001:8001"  # REST API
        ];
        volumes = [
          "/var/lib/openvino-models:/models"  # Model storage
          "/tmp/openvino:/tmp"               # Temporary files
        ];
        environment = {
          # Enable Intel GPU
          DEVICE = "GPU";
          # Log level
          LOG_LEVEL = "INFO";
        };
        extraOptions = [
          "--device=/dev/dri"  # Access to Intel GPU
          "--user=root"        # Need root for GPU access
        ];
      };

      # LiteLLM proxy - OpenAI-compatible API for multiple backends
      litellm-proxy = {
        image = "ghcr.io/berriai/litellm:main-latest";
        autoStart = false; # Start when needed
        ports = [
          "4000:4000"  # OpenAI-compatible API
        ];
        volumes = [
          "/var/lib/litellm:/app/proxy_config"
        ];
        environment = {
          LITELLM_MASTER_KEY = "sk-1234567890";  # Set your own key
        };
        extraOptions = [
          "--network=host"
        ];
      };
    };
  };

  # Install Intel compute stack for Arc GPU
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime  # OpenCL support for Intel GPUs
      intel-media-driver     # VA-API support
      vpl-gpu-rt            # Video processing
      level-zero            # Low-level GPU interface
      openvino              # OpenVINO toolkit for Intel GPUs
    ];
  };

  # Install tools and AI packages
  environment.systemPackages = with pkgs; [
    # Ollama CLI
    ollama
    
    
    # Helper scripts
    (writeShellScriptBin "setup-openvino" ''
      #!/usr/bin/env bash
      # Setup OpenVINO Model Server + Open WebUI Integration
      echo "Setting up Intel OpenVINO Model Server with Open WebUI integration..."
      
      # Create directories
      sudo mkdir -p /var/lib/openvino-models /var/lib/litellm
      sudo chown -R $USER:users /var/lib/openvino-models /var/lib/litellm
      
      # Create LiteLLM config for OpenVINO integration
      cat > /var/lib/litellm/config.yaml << 'EOF'
model_list:
  - model_name: openvino-llama
    litellm_params:
      model: openai/gpt-3.5-turbo
      api_base: http://localhost:8001/v1
      api_key: dummy-key

litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]
EOF

      echo "Setup complete!"
      echo ""
      echo "Next steps:"
      echo "1. Convert a model: pip install openvino-dev && mo --input_model model.onnx --output_dir /var/lib/openvino-models/llama"
      echo "2. Start OpenVINO: sudo systemctl start docker-openvino-model-server"
      echo "3. Start LiteLLM: sudo systemctl start docker-litellm-proxy" 
      echo "4. In Open WebUI, add OpenAI API endpoint: http://localhost:4000/v1"
      echo ""
    '')

    (writeShellScriptBin "ollama-status" ''
      #!/usr/bin/env bash
      
      echo "Ollama AI Setup Helper"
      echo "======================"
      echo ""
      echo "Ollama is running on: http://localhost:11434"
      echo "Web UI is available at: http://localhost:8080"
      echo ""
      echo "Suggested models to pull:"
      echo "  - llama3.2:latest (3B - Fast, good for coding)"
      echo "  - codellama:latest (7B - Code-focused)"
      echo "  - llama3.2:3b-instruct-q4_K_M (Quantized, efficient)"
      echo "  - qwen2.5-coder:latest (Code-focused, excellent quality)"
      echo ""
      echo "To pull a model, run:"
      echo "  ollama pull <model-name>"
      echo ""
      echo "Example:"
      echo "  ollama pull llama3.2:3b"
      echo ""
      echo "Check GPU status with:"
      echo "  intel_gpu_top"
      echo "  or"
      echo "  nvtop"
      echo ""
      echo "Intel GPU Acceleration via OpenVINO:"
      echo "  1. Start OpenVINO: sudo systemctl start docker-openvino-model-server"
      echo "  2. Start LiteLLM proxy: sudo systemctl start docker-litellm-proxy"
      echo "  3. OpenVINO REST API: http://localhost:8001/v1/config"
      echo "  4. OpenAI-compatible API: http://localhost:4000/v1/chat/completions"
      echo "  5. Models directory: /var/lib/openvino-models/"
      echo ""
      echo "Open WebUI Integration:"
      echo "  - Ollama models: Available by default"
      echo "  - OpenVINO models: Via OpenAI API settings in Open WebUI"
      echo "  - Add API endpoint: http://localhost:4000/v1"
      echo ""
      echo "Android app recommendations:"
      echo "  - Enchanted (supports custom Ollama servers)"
      echo "  - AnythingLLM Mobile"
      echo ""
      echo "VSCode extensions:"
      echo "  - Continue (continue.dev) - supports Ollama"
      echo "  - Ollama Autocoder"
      echo "  - Twinny"
      echo ""
    '')
  ];

  # Firewall rules to allow remote access
  networking.firewall = {
    allowedTCPPorts = [
      11434  # Ollama API
      8080   # Open WebUI (host networking)
      9000   # OpenVINO Model Server gRPC
      8001   # OpenVINO Model Server REST
      4000   # LiteLLM proxy (OpenAI-compatible)
    ];
  };


  # Systemd service to ensure proper GPU permissions
  systemd.services.ollama-gpu-setup = {
    description = "Setup GPU access for Ollama";
    before = [ "ollama.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Ensure render group exists and has proper permissions
      ${pkgs.coreutils}/bin/chmod a+rw /dev/dri/renderD* || true
    '';
  };

  # System tuning for AI workloads
  boot.kernel.sysctl = {
    # Increase shared memory for large models
    "kernel.shmmax" = 68719476736;  # 64GB
    "kernel.shmall" = 4294967296;
  };
}
