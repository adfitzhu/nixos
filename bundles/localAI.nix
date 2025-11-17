{ config, pkgs, lib, ... }:

{
  # Local AI bundle with Ollama and Intel Arc A770 GPU acceleration
  # Provides: Ollama LLM server, web UI, and necessary GPU support

  # Enable Ollama service
  services.ollama = {
    enable = true;
    acceleration = null; # Intel Arc uses Level Zero/OpenVINO, not CUDA/ROCm
    # Listen on all interfaces to allow Android/remote access
    host = "0.0.0.0";
    port = 11434;
    # Store models in a dedicated location
    home = "/var/lib/ollama";
    # Use all available GPUs
    environmentVariables = {
      # Intel Arc GPU configuration via Level Zero
      OLLAMA_INTEL_GPU = "1";
      # Use Level Zero backend for Intel GPUs
      OLLAMA_LLM_LIBRARY = "cpu_avx2";
      SYCL_DEVICE_FILTER = "level_zero";
      ONEAPI_DEVICE_SELECTOR = "level_zero:gpu";
      # Enable verbose logging for troubleshooting
      OLLAMA_DEBUG = "1";
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
        ports = [
          "3000:8080"
        ];
        volumes = [
          "open-webui:/app/backend/data"
        ];
        extraOptions = [
          "--add-host=host.docker.internal:host-gateway"
          "--network=host"
        ];
        environment = {
          OLLAMA_BASE_URL = "http://127.0.0.1:11434";
        };
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
    ];
  };

  # Install tools and AI packages
  environment.systemPackages = with pkgs; [
    # Ollama CLI
    ollama
    
    
    # Helper script for Ollama setup
    (pkgs.writeShellScriptBin "ollama-setup" ''
      #!/usr/bin/env bash
      
      echo "Ollama AI Setup Helper"
      echo "======================"
      echo ""
      echo "Ollama is running on: http://localhost:11434"
      echo "Web UI is available at: http://localhost:3000"
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
      3000   # Open WebUI
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
