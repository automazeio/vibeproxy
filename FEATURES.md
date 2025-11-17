# FactoryProxy High-Impact Features

This document describes the high-impact features added for AI engineers using FactoryProxy daily.

## 🏷️ Custom Model Aliases

Quickly create shortcuts for your favorite models to save typing and switch contexts faster.

### What It Does
- **Create aliases** for long model names (e.g., `fast` → `gpt-5`, `smart` → `claude-sonnet-4-5-20250929`)
- **Use aliases in requests** - the proxy automatically resolves them to full model names
- **Manage easily** - add, edit, or delete aliases from the settings window

### How to Use

**In the FactoryProxy App:**
1. Open FactoryProxy settings
2. Go to the **Aliases** tab
3. Click **Add** to create a new alias
4. Enter:
   - **Alias Name**: Short name you'll use (e.g., `fast`, `smart`, `default`)
   - **Full Model Name**: The actual model identifier (e.g., `gpt-5`, `claude-sonnet-4-5-20250929`)
5. Click **Add Alias** to save

**Using the CLI:**
```bash
# List all aliases
factory-proxy alias list

# Add an alias (use the app for now)
factory-proxy alias add fast gpt-5

# Delete an alias
factory-proxy alias delete fast
```

**In Your Code:**
Instead of:
```python
response = client.messages.create(
    model="claude-sonnet-4-5-20250929",  # Long!
    messages=[...]
)
```

Use:
```python
response = client.messages.create(
    model="smart",  # Your alias - resolved by FactoryProxy
    messages=[...]
)
```

### Examples
- Create `fast` → `gpt-5` for quick iterations
- Create `default` → `claude-sonnet-4-5-20250929` for your go-to model
- Create `thinking` → `claude-sonnet-4-5-20250929-thinking-16000` for extended thinking

## 📋 Prompt Template Library

Save your favorite prompts and system prompts for instant reuse.

### What It Does
- **Save templates** with name, description, prompt text, and system prompts
- **Organize with tags** for easy discovery
- **Store parameters** like temperature, top_p, and max_tokens with each template
- **Search templates** by name, description, or tags
- **Use variables** in templates with `{{variable}}` syntax

### How to Use

**In the FactoryProxy App:**
1. Open FactoryProxy settings
2. Go to the **Templates** tab
3. Click **Add** to create a new template
4. Fill in:
   - **Template Name**: e.g., "Code Review", "Documentation Generator"
   - **Description**: What this template is for
   - **Prompt Text**: The main prompt (supports `{{var}}` placeholders)
   - **System Prompt** (optional): System instructions for the model
   - **Tags**: Comma-separated tags like "code, review, python"
   - **Temperature, Top P, Max Tokens**: Model parameters
5. Click **Add Template** to save

**Using the CLI:**
```bash
# List all templates
factory-proxy template list

# Show a specific template
factory-proxy template show "Code Review"
```

### Template Examples

**Code Review Template:**
- **Name**: Code Review
- **Prompt**: `Please review the following {{language}} code for:\n- Potential bugs\n- Performance issues\n- Best practices violations\n\n{{code}}`
- **Tags**: code, review
- **Temperature**: 0.3

**Documentation Generator:**
- **Name**: Documentation Generator
- **Prompt**: `Generate clear and concise documentation for the following {{language}} code:\n\n{{code}}`
- **System Prompt**: `You are an expert technical writer. Write documentation that is clear, concise, and easy to understand.`
- **Tags**: docs, documentation
- **Temperature**: 0.5

**Creative Writing:**
- **Name**: Creative Story Prompt
- **Prompt**: `Write a short story about: {{theme}}`
- **Temperature**: 0.9
- **Max Tokens**: 2000

## 🔄 Quick Model Switcher

Switch between models instantly from the settings interface.

### What It Does
- **Select active model** from dropdown (displays all available models)
- **Auto-save** your selection for next session
- **Organized by service** (Claude, OpenAI, Gemini, Qwen)
- **Integration** with your LLM client configuration

### Supported Models

**Claude (Anthropic)**
- claude-opus-4-1-20250805
- claude-sonnet-4-5-20250929
- claude-3-5-sonnet-20241022
- claude-3-opus-20250219

**OpenAI (Codex)**
- gpt-5
- gpt-5-codex
- gpt-4o
- gpt-4-turbo

**Gemini (Google)**
- gemini-2.0-flash
- gemini-1.5-pro
- gemini-1.5-flash

**Qwen (Alibaba)**
- qwen-max
- qwen-plus
- qwen-turbo

## 🗂️ Conversation History (Foundation)

Basic conversation storage is now in place for future expansion.

### What It Does
- **Stores conversations** in `~/.cli-proxy-api/conversations/`
- **Tracks messages** with role, content, timestamp, and model used
- **Maintains metadata** like title, tags, creation date
- **Foundation for** future search and export features

### Data Storage
Conversations are stored as JSON files in `~/.cli-proxy-api/conversations/`:
```
~/.cli-proxy-api/
├── aliases.json
├── templates.json
└── conversations/
    ├── {conversation-id-1}.json
    ├── {conversation-id-2}.json
    └── ...
```

## 💻 Terminal Integration

The `factory-proxy` CLI tool provides command-line access to FactoryProxy features.

### Installation

Add the CLI to your PATH:
```bash
# Option 1: Symlink to /usr/local/bin
sudo ln -s /path/to/FactoryProxy/cli/factory-proxy /usr/local/bin/factory-proxy

# Option 2: Add FactoryProxy/cli to your PATH in ~/.zshrc or ~/.bashrc
export PATH="/path/to/FactoryProxy/cli:$PATH"
```

### Available Commands

```bash
# Check server status
factory-proxy status

# List aliases
factory-proxy alias list

# List templates
factory-proxy template list

# Show a specific template
factory-proxy template show "Code Review"

# Get help
factory-proxy --help
```

### Using with Scripts

```bash
#!/bin/bash

# Check if FactoryProxy is running before making API calls
if factory-proxy status > /dev/null 2>&1; then
    echo "FactoryProxy is ready!"
    # Make your LLM calls here
else
    echo "Please start FactoryProxy first"
    exit 1
fi
```

## 🔗 Integration Examples

### Using Aliases in Python

```python
import anthropic

client = anthropic.Anthropic(api_key="not-needed", base_url="http://localhost:8317")

# Use your alias instead of full model name
message = client.messages.create(
    model="smart",  # This resolves to your full model name via FactoryProxy
    max_tokens=1024,
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)
```

### Using Aliases with Extended Thinking

```python
# If you have a thinking alias defined:
# "thinking-large" -> "claude-sonnet-4-5-20250929-thinking-16000"

message = client.messages.create(
    model="thinking-large",  # Alias resolved by FactoryProxy
    max_tokens=2048,
    messages=[
        {"role": "user", "content": "Solve this complex problem..."}
    ]
)
```

### Batch Processing with Templates

```bash
#!/bin/bash

# Get list of functions to document
functions=$(ls *.py)

for func in $functions; do
    # Use template from CLI (future enhancement)
    echo "Documenting $func"
    # Your API call here
done
```

## 🎯 Workflow Tips

### Alias Workflow
1. Create aliases for your most-used models
2. Use short, memorable names (1-2 words)
3. Examples: `fast`, `slow`, `default`, `thinking`, `creative`

### Template Workflow
1. Save templates for recurring tasks
2. Use meaningful names with the task type
3. Tag templates for easy discovery
4. Test templates with your preferred temperature settings

### Quick Switching
1. Keep 3-4 common models readily available
2. Use aliases for context switching
3. Combine with templates for complete workflows

## 📊 File Locations

All feature data is stored in `~/.cli-proxy-api/`:

```
~/.cli-proxy-api/
├── aliases.json           # Model aliases (JSON)
├── templates.json         # Prompt templates (JSON)
├── model-switcher.json    # Current model selection
├── conversations/         # Chat history (JSON per conversation)
├── *.json                 # Auth tokens for services
└── config.yaml           # CLIProxyAPI configuration
```

## 🔮 Future Enhancements

These features lay the foundation for upcoming additions:
- **Conversation Export**: Save chats as Markdown, PDF, or JSON
- **Conversation Search**: Full-text search across your history
- **Advanced CLI**: Manage all features from command line
- **Analytics Dashboard**: Track token usage and costs
- **A/B Testing**: Compare model outputs side-by-side
- **VS Code Integration**: Chat panel directly in VS Code

## 📝 Notes

- All features are stored locally in `~/.cli-proxy-api/`
- Changes take effect immediately - no server restart needed
- The CLI requires the FactoryProxy server to be running for some commands
- Aliases and templates are JSON-based for easy backup and version control
