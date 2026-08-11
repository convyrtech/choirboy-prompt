---
name: diagnose
description: Diagnose whether Choirboy context was delivered by SessionStart or the load-context fallback when the user reports that the plugin, lore, hook, or memory is missing or not working.
disable-model-invocation: false
---

# Diagnose Choirboy delivery

Inspect the conversation context for the delivery marker named
`choirboy-delivery`. Do not infer delivery from an assistant acknowledgement or
from the mere presence of an installed plugin.

Report only the evidence that is present:

- `loaded`: whether a delivery marker carrying version, delivery, and
  context_sha256 attributes exists next to a `choirboy-context` block;
- `version` and `delivery` (`session-start` or `skill`);
- `context_sha256` and `nonce`, when present;
- the next corrective action.

If no valid marker is present, explain that registration or hook execution is
not proven and ask the user to invoke `/choirboy-prompt:load-context` in Claude
Code. In Claude Chat or Cowork, tell the user to select the **load-context** skill
or ask Claude to “load Choirboy context”. Do not recommend clearing Claude
memory until delivery has first been proven.
