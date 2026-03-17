#!/usr/bin/env python3
"""Search Spellbook skills and agents by semantic similarity.

Embeds a query with Gemini Embedding 2, compares against pre-computed
embeddings.json, returns top matches ranked by cosine similarity.

Usage:
    python3 scripts/search-embeddings.py "payment webhook integration"
    python3 scripts/search-embeddings.py --project-dir /path/to/project
    python3 scripts/search-embeddings.py "query" --top 10 --type skill

Requires: GEMINI_API_KEY or GOOGLE_API_KEY env var.
"""

import json
import math
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
EMBEDDINGS_FILE = REPO_ROOT / "embeddings.json"
MODEL = "gemini-embedding-2-preview"
DEFAULT_TOP = 15
DEFAULT_DIMS = 768


def cosine_similarity(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    mag_a = math.sqrt(sum(x * x for x in a))
    mag_b = math.sqrt(sum(x * x for x in b))
    if mag_a == 0 or mag_b == 0:
        return 0.0
    return dot / (mag_a * mag_b)


def embed_query(client, text: str, dims: int) -> list[float]:
    result = client.models.embed_content(
        model=MODEL,
        contents=text,
        config={
            "output_dimensionality": dims,
            "task_type": "RETRIEVAL_QUERY",
        },
    )
    return result.embeddings[0].values


def synthesize_project_context(project_dir: Path) -> str:
    """Read project signals and synthesize a description for embedding."""
    parts = []

    # CLAUDE.md or README
    for name in ["CLAUDE.md", "README.md"]:
        f = project_dir / name
        if f.exists():
            text = f.read_text(encoding="utf-8")[:2000]
            parts.append(text)
            break

    # package.json dependencies
    pkg = project_dir / "package.json"
    if pkg.exists():
        try:
            data = json.loads(pkg.read_text(encoding="utf-8"))
            deps = list(data.get("dependencies", {}).keys())
            dev_deps = list(data.get("devDependencies", {}).keys())
            if deps:
                parts.append(f"Dependencies: {', '.join(deps[:30])}")
            if dev_deps:
                parts.append(f"Dev dependencies: {', '.join(dev_deps[:20])}")
        except json.JSONDecodeError:
            pass

    # go.mod
    gomod = project_dir / "go.mod"
    if gomod.exists():
        text = gomod.read_text(encoding="utf-8")[:1000]
        parts.append(f"Go module: {text}")

    # mix.exs
    mixfile = project_dir / "mix.exs"
    if mixfile.exists():
        text = mixfile.read_text(encoding="utf-8")[:1000]
        parts.append(f"Elixir project: {text}")

    # Cargo.toml
    cargo = project_dir / "Cargo.toml"
    if cargo.exists():
        text = cargo.read_text(encoding="utf-8")[:1000]
        parts.append(f"Rust project: {text}")

    # Directory structure
    dirs = [
        d.name
        for d in sorted(project_dir.iterdir())
        if d.is_dir() and not d.name.startswith(".")
    ][:20]
    if dirs:
        parts.append(f"Directories: {', '.join(dirs)}")

    if not parts:
        return "General software project"

    return "\n".join(parts)


def main():
    top_n = DEFAULT_TOP
    type_filter = None
    query = None
    project_dir = None

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--top" and i + 1 < len(args):
            top_n = int(args[i + 1])
            i += 2
        elif args[i] == "--type" and i + 1 < len(args):
            type_filter = args[i + 1]
            i += 2
        elif args[i] == "--project-dir" and i + 1 < len(args):
            project_dir = Path(args[i + 1])
            i += 2
        elif not args[i].startswith("-"):
            query = args[i]
            i += 1
        else:
            i += 1

    if not query and not project_dir:
        print("Usage: search-embeddings.py <query> | --project-dir <path>", file=sys.stderr)
        sys.exit(1)

    # Load embeddings
    if not EMBEDDINGS_FILE.exists():
        print(f"Error: {EMBEDDINGS_FILE} not found. Run generate-embeddings.py first.", file=sys.stderr)
        sys.exit(1)

    data = json.loads(EMBEDDINGS_FILE.read_text(encoding="utf-8"))
    items = data["items"]
    dims = data["dimensions"]

    if type_filter:
        items = [item for item in items if item["type"] == type_filter]

    # Build query text
    if project_dir:
        query_text = synthesize_project_context(project_dir)
        print(f"Project context ({len(query_text)} chars):", file=sys.stderr)
        print(f"  {query_text[:200]}...", file=sys.stderr)
    else:
        query_text = query

    # Embed query
    from google import genai
    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY or GOOGLE_API_KEY required", file=sys.stderr)
        sys.exit(1)
    client = genai.Client(api_key=api_key)
    query_vec = embed_query(client, query_text, dims)

    # Rank by similarity
    scored = []
    for item in items:
        sim = cosine_similarity(query_vec, item["embedding"])
        scored.append((sim, item))
    scored.sort(key=lambda x: x[0], reverse=True)

    # Output
    print(f"\nTop {top_n} matches for: {query_text[:80]}{'...' if len(query_text) > 80 else ''}\n")
    for rank, (score, item) in enumerate(scored[:top_n], 1):
        marker = "*" if score > 0.7 else " " if score > 0.5 else "."
        print(f"  {marker} {rank:2d}. [{item['type']:5s}] {item['fqn']}")
        print(f"       score: {score:.4f}  — {item['description'][:100]}")
        print()


if __name__ == "__main__":
    main()
