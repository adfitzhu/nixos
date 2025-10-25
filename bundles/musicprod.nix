{ config, pkgs, lib, ... }:

{
  # Music Production packages
  environment.systemPackages = with pkgs; [
    ardour               # Digital Audio Workstation
    lmms                 # Linux MultiMedia Studio
    hydrogen             # Advanced drum machine
    wireplumber           # Audio session manager for PipeWire
    rakarrack            # Virtual guitar effects processor
    audacity            # Audio editor and recorder

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