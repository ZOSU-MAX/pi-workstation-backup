# User npm global prefix (codex CLI lives here; /usr/local/bin is root-owned, no sudo)
if [ -d /opt/data/.npm-global/bin ]; then
  PATH="/opt/data/.npm-global/bin:$PATH"
  export PATH
fi

# Custom model provider for codex (see ~/.codex/config.toml [model_providers.longcat])
if [ -z "$OPENAI_API_KEY" ]; then
  export OPENAI_API_KEY="ak_2pE32F1TF6oJ5oR7h37jm5RX8Jp23"
fi

# opencode uses a provider-scoped key (see ~/.config/opencode/opencode.jsonc)
if [ -z "$LONGCAT_API_KEY" ]; then
  export LONGCAT_API_KEY="$OPENAI_API_KEY"
fi

export PATH="/opt/data/home/.local/bin:$PATH"
