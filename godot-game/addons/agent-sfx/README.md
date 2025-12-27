# Agent SFX - AI-Powered Sound Effect Generator

A Godot 4.4+ editor plugin that analyzes your game code and automatically generates sound effect suggestions using AI.

## Features

- **Code Analysis**: Automatically analyzes your `.gd` and `.tscn` files to detect game events, actions, and interactions
- **AI-Powered Suggestions**: Uses LLM to intelligently suggest sound effects based on your code
- **User Review**: Review, edit, and approve sound suggestions before generation
- **ElevenLabs Integration**: Generate actual audio files using ElevenLabs API (coming in Phase 2)

## Installation

1. Copy the `addons/agent-sfx` folder to your Godot project's `addons` directory
2. Open your project in Godot
3. Go to **Project → Project Settings → Plugins**
4. Enable the **Agent SFX** plugin

## Setup

1. **Get API Keys**:
   - Groq AI API key for LLM analysis: https://console.groq.com
   - ElevenLabs API key for audio generation: https://elevenlabs.io

2. **Configure API Keys**:
   - Go to **Project → Project Settings → General → Agent SFX**
   - Enter your API keys in the settings

   OR create `res://GROQ_API_KEY.txt` and `res://ELEVEN_LABS_API_KEY.txt` files
   - Note: Old `FAL_API_KEY.txt` files are still supported for backward compatibility

## Usage

1. Open the **Agent SFX** dock (should appear on the left side of the editor)
2. Click **"Analyze Code"** to scan your project
3. Wait for the AI to analyze and suggest sound effects
4. Review the suggestions in the review panel
5. Edit names, descriptions, or remove unwanted suggestions
6. Click **"Generate Audio Files"** to create the audio (Phase 2)

## How It Works

1. **Code Analysis**: Scans all `.gd` files for:
   - Function names (especially `_on_*` signal handlers and action functions)
   - State machines (`enum STATE`)
   - Signal definitions
   - Audio-related code patterns

2. **Scene Analysis**: Scans `.tscn` files for:
   - RichTextLabel nodes (dialogs)
   - Signal connections
   - Area2D/CollisionShape2D nodes (interactions)

3. **LLM Analysis**: Sends code context to LLM to generate intelligent sound effect suggestions

4. **User Review**: You can review, edit, and approve suggestions before generation

## Features Status

✅ Code analysis  
✅ Scene analysis  
✅ LLM integration  
✅ Review panel  
✅ Audio generation (ElevenLabs)  
✅ Audio preview  
✅ Auto-wiring system  
✅ Caching for performance

## Requirements

- Godot 4.4+
- Groq AI API key (for LLM analysis)
- ElevenLabs API key (for audio generation)

## License

MIT License

