# ElevenLabs Integration Guide

## Overview
This Godot project includes a complete ElevenLabs API integration for generating:
- **Sound Effects** (`eleven_sfx.gd`) - Generate game sound effects from text descriptions
- **Dialog Audio** (`eleven_dialog.gd`) - Convert text to speech using various voices

## API Compliance
✅ **Fully compliant with ElevenLabs API v1 specification**
- Correct endpoints and HTTP methods
- Proper authentication headers
- Valid request/response handling
- Parameter validation according to API limits

## Setup Instructions

### 1. API Key Configuration
- Your API key is stored in `ELEVEN_LABS_API_KEY.txt`
- Current key: `sk_da6fb1812b709cba9fe2995c6f1bb0955eade3041d7eb5a1`
- Keep this file secure and never commit to version control

### 2. Directory Structure
```
godot-game/
├── lib/
│   ├── eleven_sfx.gd          # Sound effects generator
│   ├── eleven_sfx.tscn        # Sound effects scene
│   ├── eleven_dialog.gd       # Dialog generator  
│   └── eleven_dialog.tscn     # Dialog scene
├── godotai/                   # Generated audio files
│   └── dialog/               # Dialog audio files
└── ELEVEN_LABS_API_KEY.txt   # API key (gitignored)
```

## Sound Effects Generator (`eleven_sfx.gd`)

### Features
- **Endpoint**: `/v1/sound-generation`
- **Output Format**: MP3 44.1kHz 128kbps
- **Configurable Parameters**:
  - `duration_seconds`: 0.5-30.0 seconds
  - `prompt_influence`: 0.0-1.0 (how closely to follow prompt)
  - `model_id`: Sound generation model
  - `loop_sound`: Create seamless loops

### Usage
1. Add `eleven_sfx.tscn` to your scene
2. Set `audio_name` (file name)
3. Set `description` (what sound to generate)
4. Adjust parameters as needed
5. Click "Generate Audio" in editor

### Example
```gdscript
# In editor inspector:
audio_name = "footstep_grass"
description = "character walking on grass"
duration_seconds = 1.0
prompt_influence = 0.5
```

## Dialog Generator (`eleven_dialog.gd`)

### Features
- **Endpoint**: `/v1/text-to-speech/{voice_id}`
- **Voice**: Adam (pNInz6obpgDQGcFmaJgB) - verified working voice
- **Model**: eleven_multilingual_v2
- **Output Format**: MP3 44.1kHz 128kbps
- **Text Limit**: 2500 characters (free tier)

### Configurable Parameters
- `voice_id`: ElevenLabs voice identifier
- `model_id`: TTS model to use
- `language_code`: ISO 639-1 code (optional)
- `enable_logging`: Set false for zero retention mode

### Usage
1. Add `eleven_dialog.tscn` to your scene
2. Set `audio_name` (file name)
3. Set `dialog` (text to convert)
4. Optionally set `language_code` (e.g., "en", "es")
5. Click "Generate Dialog Audio" in editor

### Example
```gdscript
# In editor inspector:
audio_name = "welcome_message"
dialog = "Welcome to our magical world, brave adventurer!"
language_code = "en"
```

## Error Handling
Both implementations include comprehensive error handling:
- Network connectivity issues
- API authentication errors
- Parameter validation
- File system errors
- Response validation

## API Limits & Compliance
- **Free Tier**: 10,000 characters/month
- **Text Length**: Max 2500 characters per request (free users)
- **Duration**: 0.5-30 seconds for sound effects
- **Rate Limits**: Handled by request state management

## Testing
Run `test_elevenlabs_integration.gd` from Godot Editor (Tools > Execute Script) to validate your setup.

## Troubleshooting

### Common Issues
1. **"API key file not found"**: Ensure `ELEVEN_LABS_API_KEY.txt` exists
2. **"Network error"**: Check internet connection
3. **"Response code 401"**: Invalid API key
4. **"Response code 422"**: Invalid parameters (check text length, duration, etc.)
5. **"Failed to open file"**: Check file permissions

### Debug Tips
- Check Godot's output panel for detailed error messages
- Verify API key format (should start with "sk_")
- Ensure text is within character limits
- Check that voice_id is valid

## Security Notes
- API key is stored locally, not in code
- File is gitignored to prevent accidental commits
- Consider using environment variables in production

## Performance
- Requests are asynchronous (non-blocking)
- State management prevents spam requests
- Files are cached locally after generation