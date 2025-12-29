{ config, pkgs, lib, ... }:

{
  # Enable JACK support and low-latency audio for music production
  # Override/extend the existing PipeWire configuration from desktop bundle
  services.pipewire = {
    jack.enable = true;  # Enable JACK compatibility
    
    # Low-latency configuration
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 64;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 1024;
      };
    };
  };
  
  # Add user to audio group for low-latency access
  users.groups.audio = {};
  
  # Optimize system for audio production
  security.pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio"; type = "-"; value = "99"; }
    { domain = "@audio"; item = "nofile"; type = "soft"; value = "99999"; }
    { domain = "@audio"; item = "nofile"; type = "hard"; value = "99999"; }
    
    # Additional limits for gaming/Wine ESYNC support
    { domain = "*"; item = "nofile"; type = "soft"; value = "524288"; }
    { domain = "*"; item = "nofile"; type = "hard"; value = "1048576"; }
  ];

  # Music Production packages
  environment.systemPackages = with pkgs; [
    ardour               # Digital Audio Workstation
    lmms                 # Linux MultiMedia Studio
    hydrogen             # Advanced drum machine
    wireplumber          # Audio session manager for PipeWire
    rakarrack            # Virtual guitar effects processor
    audacity             # Audio editor and recorder

    guitarix
    rubberband
    lsp-plugins
    x42-plugins
    
    # JACK utilities and tools
    qjackctl             # JACK control GUI
    jack-example-tools   # JACK example clients and utilities
    carla                # Audio plugin host with JACK support
    

    # muse-sequencer      # MIDI/Audio sequencer
    # qtractor            # Audio/MIDI multi-track sequencer
    # calf-plugins        # Audio effects plugins
    # zynaddsubfx         # Software synthesizer
    # carla               # Audio plugin host
    # jack2               # Low-latency audio server
    # pulseaudio          # Sound system
    # pulseaudio-ctl      # PulseAudio command-line control tool
    # alsa-utils         # ALSA utilities for sound card management
    # qsynth              # GUI for FluidSynth soundfont synthesizer
    # fluidsynth         # Real-time software synthesizer
    # sox                 # Sound processing tools
    # ffmpeg              # Multimedia framework for audio/video processing         

  ];




}