# CLAUDE.md — AI Agent Instructions

## Overview
This repository uses an **AI Code Knowledge System** to provide a structured index of the codebase. All extracted knowledge is stored in the `.knowledge/` directory, which includes symbol graphs, dependency maps, and LLM-generated file summaries. This system is designed to reduce token overhead and provide high-level architectural insights without requiring agents to scan every file.

## MCP Tools Available

### Composite Tools (use these first — they reduce tool calls by 60-70%)
- `get_project_overview(depth?)`: **Start here.** Returns file tree, tech stack, modules, symbol counts, and key entry points in a single call. Eliminates the need for `ls`, `health_check`, or path-guessing.
- `get_module_context(module)`: Get everything about a module: file summaries, exported symbols, internal dependencies, shared patterns, and role in the architecture. Replaces multiple `get_file_summary` calls.
- `get_implementation_context(file, includePatterns?)`: Rich context for a single file: summary, all symbols with signatures, related files, import/export graph, and code pattern fingerprint. Use before modifying a file.
- `get_cumulative_context(files[], query?)`: Build cumulative context across multiple files with optional query focus. Use when analyzing cross-cutting concerns or tracing a feature end-to-end.
- `get_feature_context(feature)`: Get full context for a named feature: all files, symbols, and patterns that implement it. Use when working on a product-level capability.
- `get_batch_summaries(files[])`: Get compact summaries for up to 20 files in one call. Use when you know which files you need.

### Targeted Query Tools
- `find_symbol(name, type?)`: Locate class, function, or interface definitions across the project.
- `find_callers(symbol, maxDepth?)`: Identify all symbols that call a specific function or class method.
- `get_dependencies(module, depth?)`: Retrieve module-level or file-level dependency relationships.
- `get_file_summary(file)`: Get a high-level overview of a single file. Prefer `get_implementation_context` for richer detail.
- `get_directory_tree(path?)`: Get a structured directory tree. Use when you need the file layout of a subdirectory without full file content.
- `search_architecture(query)`: Query the human-authored architecture documentation for system-wide patterns.
- `semantic_search(query)`: Natural-language search across all indexed file summaries and symbols. Use when you don't know the exact name of what you're looking for.
- `get_code_patterns(pattern?)`: Retrieve recurring code patterns (e.g. service structure, error handling, naming conventions) to write consistent new code.
- `explore_graph(startNode, direction?, depth?)`: Traverse the symbol/dependency graph from a starting node. Use for deep impact analysis or tracing data flow.
- `health_check(verbose?)`: Knowledge base status. Use `verbose=true` for tech stack and file tree.

### Template & Artifact Tools
- `find_template_file(name)`: Locate a code template by name. Use before generating boilerplate to ensure consistency with project scaffolding.
- `get_artifact_schema(artifact)`: Get the schema definition for a tracked artifact type (e.g. plan, screen, migration).
- `get_artifact_store_path(artifact)`: Get the file-system path where a specific artifact type is stored.
- `get_static_data_schema(name)`: Get the schema for static data files. Use when reading or writing JSON/YAML config structures.
- `validate_artifact_draft(artifact, draft)`: Validate a draft artifact against its schema before writing it to disk.
- `rebuild_knowledge()`: Trigger a full rebuild of the knowledge index. Use after a large refactor or when `health_check` reports stale data.


## Preferred Tool Order
Follow this order to minimize tool calls and maximize context efficiency:
1. `get_project_overview` (first call — understand the project structure)
2. `get_module_context` (understand a specific area of the codebase)
3. `get_feature_context` (understand a product-level feature end-to-end)
4. `get_implementation_context` (understand a specific file before modifying it)
5. `get_cumulative_context` (cross-file analysis or feature tracing)
6. `get_batch_summaries` (when you know which files you need context for)
7. `find_symbol` (to locate specific logic by name)
8. `find_callers` (to understand impact or usage patterns)
9. `explore_graph` (deep dependency or data-flow traversal)
10. `get_dependencies` (to understand module relationships)
11. `semantic_search` (when you don't know exact symbol names)
12. `get_code_patterns` (before writing new code to stay consistent)
13. `get_file_summary` (single file, lightweight — prefer `get_implementation_context`)
14. `get_directory_tree` (targeted subtree layout without full content)
15. `search_architecture` (to understand high-level system design)
16. `find_template_file` (before generating boilerplate)
17. `get_artifact_schema` / `validate_artifact_draft` (when creating/updating artifacts)
18. `native grep` (only as a last resort if MCP tools fail to find a pattern)

## When to Use Each Tool

### `get_project_overview`
**Always call this first** when working with a new or unfamiliar project. It gives you the file tree, tech stack, module structure, and entry points — everything you need to start navigating without any `ls` commands.
*Example: "What does this project look like?"*

### `get_module_context`
Use when you need to understand an entire module before diving into specific files. Returns all file summaries, exported symbols, and internal structure in one call.
*Example: "What's in the `scripts` module?"*

### `get_implementation_context`
Use before modifying a file. Gives you everything: the file's purpose, all its symbols, which files import it, siblings in the same directory, and a pattern fingerprint so you can write consistent code.
*Example: "I need to modify `src/services/auth.ts` — what should I know?"*

### `get_batch_summaries`
Use when you've identified multiple files and need a quick overview of all of them at once.
*Example: "Summarize these 5 files for me"*

### `find_symbol`
Use when you know the name of a class, function, or interface but don't know where it is defined.
*Example: "Where is the `AuthService` class defined?"*

### `find_callers`
Use to trace how a specific symbol is used or to find where a function is invoked. Critical for impact analysis.
*Example: "Which components call the `deleteUser` method?"*

### `get_dependencies`
Use to understand the relationship between different parts of the system. Helps identify entry points and shared utilities.
*Example: "What are the dependencies of the `orders` module?"*

### `get_file_summary`
Use for a quick, lightweight summary of a single file. For richer context, prefer `get_implementation_context`.
*Example: "What does `src/services/logger.ts` do?"*

### `search_architecture`
Use for high-level questions about the system's design or to find which modules handle specific responsibilities.
*Example: "How is authentication handled in this project?"*

### `semantic_search`
Use when you don't know the exact name of a function, class, or file. Searches indexed summaries using natural language.
*Example: "Which file handles rate limiting for API requests?"*

### `get_code_patterns`
Use before writing new code to understand recurring patterns (service structure, error handling, naming conventions) so new code is consistent with the rest of the codebase.
*Example: "How are repository classes structured in this project?"*

### `explore_graph`
Use when you need to traverse the symbol or dependency graph more deeply than `find_callers` allows — e.g. tracing data flow across multiple layers or finding transitive dependents.
*Example: "What is the full call chain from the API handler to the database for plan creation?"*

### `get_cumulative_context`
Use when analyzing a feature or concern that spans multiple files and you want a synthesized view rather than individual file summaries.
*Example: "Give me context across all files involved in audio playback."*

### `get_feature_context`
Use when starting work on a product-level feature. Returns every file, symbol, and pattern involved in implementing it.
*Example: "What code implements the onboarding flow?"*

### `get_directory_tree`
Use when you need the layout of a specific subdirectory without loading file contents. Lighter than `get_project_overview` for deep subtrees.
*Example: "What files are under `app/lib/screens/plan_editor/`?"*

### `find_template_file`
Use before generating scaffolding or boilerplate to check if a project template already exists.
*Example: "Is there a template for creating a new NestJS module?"*

### `get_artifact_schema` / `get_static_data_schema`
Use when reading or writing structured data files (JSON, YAML, migrations) to ensure the shape is correct before touching the file.
*Example: "What fields does a plan artifact require?"*

### `validate_artifact_draft`
Use after composing a new artifact draft to check it against the schema before writing it to disk.
*Example: "Validate this new plan template before I save it."*

### `get_artifact_store_path`
Use to find where a specific artifact type is persisted on disk.
*Example: "Where are plan artifacts stored?"*

### `rebuild_knowledge`
Use to trigger a full rebuild of the knowledge index after a large refactor or when `health_check` reports stale/missing data. Prefer this over `npm run build-knowledge` when inside an agent session.
*Example: "The knowledge index seems out of date — rebuild it."*

## DO NOT
- **Do not** use `ls` to explore directories — use `get_project_overview` or `get_directory_tree` instead.
- **Do not** call `get_file_summary` in a loop — use `get_batch_summaries` or `get_module_context`.
- **Do not** read full file contents before checking `get_implementation_context` or `get_file_summary`.
- **Do not** assume the directory structure is the only source of truth; use `get_dependencies`.
- **Do not** skip using MCP tools when unsure about where a feature is implemented.
- **Do not** write new code without first calling `get_code_patterns` to match project conventions.
- **Do not** write new artifacts without validating with `validate_artifact_draft`.
- **Do not** use `semantic_search` as a substitute for `find_symbol` when you already know the exact name.
- **Do not** run `npm run build-knowledge` manually when inside an agent session — use `rebuild_knowledge` instead.

## Knowledge Freshness
The knowledge index is updated automatically if the `watch` script is running. If you suspect the index is stale (e.g., after a large refactor), you can trigger a manual rebuild using `npm run build-knowledge`. Always check `.knowledge/index.json` for the `lastBuilt` timestamp if in doubt.
