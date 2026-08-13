# Graphify reference: transcription

Version scope: Graphify revision `0b2bd938c4a48e91d27f0ba09b96409e0a36c78a`. Transcription is an optional non-code workflow and is not available in the default wrapper extras used by this repository.

Proceed only when the user explicitly requests audio/video ingestion. Before running anything:

1. Check the root `graphify --help` with the intended extras enabled.
2. Confirm the installed revision exposes a transcription command and use exactly the syntax it reports.
3. Explain that enabling extras may download Python packages and media/model dependencies.
4. Confirm network, storage, privacy, and API-key implications for the selected backend.

The Nix wrapper selects extras through `GRAPHIFY_UV_EXTRAS`; changing it may rebuild the wrapper-managed environment. Do not silently set it to `all`, and do not assume a Whisper model or provider.

After transcription, treat transcripts as semantic document inputs. They are not part of a `--code-only` extraction and may require an LLM provider/API key during graph extraction.

If the root help does not advertise transcription under the selected extras, stop and report that it is unavailable for this pinned revision/configuration. Never import Graphify internals, run `python -m graphify...`, or invoke `graphify-out/.graphify_python`.
