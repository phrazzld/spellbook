import type { SearchRequest, SearchResult, ProviderAdapter } from "./provider-adapter";
import type { QueryCache } from "./cache";
import { dedupeByCanonicalUrl, normalizeQuery } from "./query-utils";
import { appendLineWithRotation } from "../../extensions/shared/log-rotation";

export interface OrchestratorOptions {
  cache?: QueryCache<SearchResult[]>;
  logPath?: string;
}

export interface SearchRunMeta {
  cacheHit: boolean;
  providerUsed: ProviderAdapter["name"] | null;
  providerChain: ProviderAdapter["name"][];
}

const WEB_SEARCH_LOG_MAX_BYTES = clampInt(
  Number(process.env.PI_WEB_SEARCH_LOG_MAX_BYTES ?? 10 * 1024 * 1024),
  128 * 1024,
  512 * 1024 * 1024,
);
const WEB_SEARCH_LOG_MAX_BACKUPS = clampInt(
  Number(process.env.PI_WEB_SEARCH_LOG_MAX_BACKUPS ?? 5),
  1,
  20,
);
const WEB_SEARCH_LOG_ROTATE_CHECK_MS = clampInt(
  Number(process.env.PI_WEB_SEARCH_LOG_ROTATE_CHECK_MS ?? 30_000),
  1_000,
  10 * 60 * 1000,
);

interface LogEvent {
  ts: string;
  event: string;
  query: string;
  command: SearchRequest["command"];
  provider?: ProviderAdapter["name"];
  count?: number;
  detail?: string;
}

export class WebSearchOrchestrator {
  private readonly providers: ProviderAdapter[];
  private readonly cache?: QueryCache<SearchResult[]>;
  private readonly logPath?: string;

  constructor(providers: ProviderAdapter[], options: OrchestratorOptions = {}) {
    if (providers.length === 0) {
      throw new Error("providers must not be empty");
    }
    this.providers = providers;
    this.cache = options.cache;
    this.logPath = options.logPath;
  }

  async search(request: SearchRequest): Promise<SearchResult[]> {
    const { results } = await this.searchWithMeta(request);
    return results;
  }

  async searchWithMeta(
    request: SearchRequest
  ): Promise<{ results: SearchResult[]; meta: SearchRunMeta }> {
    const providerChain = this.providers.map((provider) => provider.name);

    if (this.cache) {
      const cached = await this.cache.get(request);
      if (cached) {
        await this.log({ event: "cache_hit", request, count: cached.length });
        return {
          results: cached,
          meta: {
            cacheHit: true,
            providerUsed: cached[0]?.source_provider ?? null,
            providerChain,
          },
        };
      }
    }

    let lastError: unknown = null;
    await this.log({ event: "cache_miss", request });

    for (const provider of this.providers) {
      try {
        const results = await provider.search(request);
        if (results.length === 0) {
          await this.log({ event: "provider_empty", request, provider });
          continue;
        }

        const deduped = dedupeByCanonicalUrl(results);
        if (this.cache) {
          await this.cache.set(request, deduped);
        }

        await this.log({
          event: "provider_success",
          request,
          provider,
          count: deduped.length,
        });
        return {
          results: deduped,
          meta: {
            cacheHit: false,
            providerUsed: provider.name,
            providerChain,
          },
        };
      } catch (error) {
        lastError = error;
        await this.log({
          event: "provider_error",
          request,
          provider,
          detail: String(error),
        });
      }
    }

    await this.log({
      event: "all_providers_failed",
      request,
      detail: lastError ? String(lastError) : "no results",
    });

    if (lastError) {
      throw lastError;
    }
    return {
      results: [],
      meta: {
        cacheHit: false,
        providerUsed: null,
        providerChain,
      },
    };
  }

  private async log(input: {
    event: string;
    request: SearchRequest;
    provider?: ProviderAdapter;
    count?: number;
    detail?: string;
  }): Promise<void> {
    if (!this.logPath) {
      return;
    }

    const payload: LogEvent = {
      ts: new Date().toISOString(),
      event: input.event,
      query: normalizeQuery(input.request.query),
      command: input.request.command,
      provider: input.provider?.name,
      count: input.count,
      detail: input.detail,
    };

    await appendLineWithRotation(this.logPath, `${JSON.stringify(payload)}\n`, {
      maxBytes: WEB_SEARCH_LOG_MAX_BYTES,
      maxBackups: WEB_SEARCH_LOG_MAX_BACKUPS,
      checkIntervalMs: WEB_SEARCH_LOG_ROTATE_CHECK_MS,
    });
  }
}

function clampInt(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) {
    return min;
  }
  return Math.max(min, Math.min(max, Math.floor(value)));
}
