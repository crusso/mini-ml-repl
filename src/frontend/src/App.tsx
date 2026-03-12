import { ScrollArea } from "@/components/ui/scroll-area";
import { Cpu, Loader2, Terminal } from "lucide-react";
import {
  type KeyboardEvent,
  useCallback,
  useEffect,
  useRef,
  useState,
} from "react";
import { EnvPanel } from "./components/EnvPanel";
import { ExamplesPanel } from "./components/ExamplesPanel";
import {
  type HistoryEntry,
  ReplEmptyState,
  ReplOutput,
} from "./components/ReplOutput";
import { useEvaluate, useGetEnv, useReset } from "./hooks/useBackend";

let entryIdCounter = 0;
function nextId() {
  return ++entryIdCounter;
}

export default function App() {
  const [input, setInput] = useState("");
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [inputHistory, setInputHistory] = useState<string[]>([]);
  const [, setHistoryIndex] = useState(-1);
  const [pendingId, setPendingId] = useState<number | null>(null);

  const scrollEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const { data: envBindings = [], isLoading: isEnvLoading } = useGetEnv();
  const { mutateAsync: evaluate, isPending: isEvaluating } = useEvaluate();
  const { mutateAsync: reset, isPending: isResetting } = useReset();

  // Auto-scroll to bottom when history changes
  // biome-ignore lint/correctness/useExhaustiveDependencies: history triggers the scroll
  useEffect(() => {
    scrollEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [history]);

  // Focus input on mount
  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const handleSubmit = useCallback(async () => {
    const trimmed = input.trim();
    if (!trimmed || isEvaluating) return;

    const inputId = nextId();
    const pendingEntryId = nextId();

    // Optimistic: show input line immediately
    setHistory((prev) => [
      ...prev,
      { kind: "input", text: trimmed, id: inputId },
      { kind: "pending", text: "evaluating...", id: pendingEntryId },
    ]);
    setPendingId(pendingEntryId);

    // Track input history
    setInputHistory((prev) => {
      const deduped = prev.filter((h) => h !== trimmed);
      return [trimmed, ...deduped].slice(0, 100);
    });
    setHistoryIndex(-1);
    setInput("");

    try {
      const result = await evaluate(trimmed);

      setHistory((prev) => {
        // Remove the pending entry, add result
        const filtered = prev.filter((e) => e.id !== pendingEntryId);
        if (result.__kind__ === "ok") {
          return [
            ...filtered,
            {
              kind: "output",
              value: result.ok.value,
              typeStr: result.ok.typeStr,
              id: nextId(),
            },
          ];
        }
        return [
          ...filtered,
          { kind: "error", message: result.err, id: nextId() },
        ];
      });
    } catch (err) {
      setHistory((prev) => {
        const filtered = prev.filter((e) => e.id !== pendingEntryId);
        return [
          ...filtered,
          {
            kind: "error",
            message: err instanceof Error ? err.message : "Unknown error",
            id: nextId(),
          },
        ];
      });
    } finally {
      setPendingId(null);
    }
  }, [input, isEvaluating, evaluate]);

  const handleKeyDown = useCallback(
    (e: KeyboardEvent<HTMLInputElement>) => {
      if (e.key === "Enter") {
        e.preventDefault();
        handleSubmit();
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setHistoryIndex((prev) => {
          const next = Math.min(prev + 1, inputHistory.length - 1);
          if (inputHistory[next] !== undefined) {
            setInput(inputHistory[next]);
          }
          return next;
        });
      } else if (e.key === "ArrowDown") {
        e.preventDefault();
        setHistoryIndex((prev) => {
          const next = prev - 1;
          if (next < 0) {
            setInput("");
            return -1;
          }
          if (inputHistory[next] !== undefined) {
            setInput(inputHistory[next]);
          }
          return next;
        });
      }
    },
    [handleSubmit, inputHistory],
  );

  const handleReset = useCallback(async () => {
    await reset();
    setHistory([
      {
        kind: "system",
        message: "Session reset. Environment cleared.",
        id: nextId(),
      },
    ]);
    setInput("");
    setHistoryIndex(-1);
    inputRef.current?.focus();
  }, [reset]);

  const handleExampleSelect = useCallback((expr: string) => {
    setInput(expr);
    inputRef.current?.focus();
  }, []);

  return (
    <div className="h-screen w-screen bg-background flex flex-col overflow-hidden font-sans">
      {/* Top bar */}
      <header className="flex items-center justify-between px-4 py-2.5 border-b border-border bg-card/50 shrink-0">
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1.5">
            <div className="w-3 h-3 rounded-full bg-terminal-error/70" />
            <div className="w-3 h-3 rounded-full bg-accent/70" />
            <div className="w-3 h-3 rounded-full bg-terminal-green/70" />
          </div>
          <div className="flex items-center gap-2 ml-2">
            <Terminal className="h-4 w-4 text-terminal-green text-glow-sm" />
            <span className="font-mono text-sm font-semibold text-terminal-green text-glow-sm">
              Mini-ML
            </span>
            <span className="font-mono text-xs text-muted-foreground hidden sm:inline">
              — Hindley-Milner Type Inference
            </span>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Cpu className="h-3.5 w-3.5 text-muted-foreground/50" />
          <span className="font-mono text-xs text-muted-foreground/50">
            ICP Canister
          </span>
        </div>
      </header>

      {/* Main content */}
      <div className="flex flex-1 min-h-0 overflow-hidden">
        {/* Left: REPL panel (~70%) */}
        <main className="flex flex-col flex-1 min-w-0 border-r border-border relative scanlines">
          {/* Output area */}
          <ScrollArea className="flex-1 min-h-0">
            <div className="p-4 pb-2 min-h-full">
              {history.length === 0 ? (
                <ReplEmptyState />
              ) : (
                <ReplOutput entries={history} />
              )}

              {/* Loading indicator */}
              {isEvaluating && pendingId !== null && (
                <div
                  className="flex items-center gap-2 py-1 pl-4 mt-1"
                  data-ocid="repl.loading_state"
                >
                  <Loader2 className="h-3 w-3 animate-spin text-terminal-green/60" />
                  <span className="font-mono text-xs text-muted-foreground/50 italic">
                    type checking…
                  </span>
                </div>
              )}

              <div ref={scrollEndRef} />
            </div>
          </ScrollArea>

          {/* Examples collapsible */}
          <ExamplesPanel onSelect={handleExampleSelect} />

          {/* Input row */}
          <div className="px-4 py-3 border-t border-border bg-card/30 shrink-0">
            <div className="flex items-center gap-3">
              <span
                className={`font-mono text-base font-bold shrink-0 transition-colors select-none ${
                  isEvaluating
                    ? "text-muted-foreground/40"
                    : "text-terminal-prompt text-glow-sm"
                }`}
              >
                &gt;
              </span>
              <input
                ref={inputRef}
                type="text"
                value={input}
                onChange={(e) => {
                  setInput(e.target.value);
                  setHistoryIndex(-1);
                }}
                onKeyDown={handleKeyDown}
                disabled={isEvaluating}
                placeholder={isEvaluating ? "" : "Enter expression…"}
                className="flex-1 bg-transparent font-mono text-sm text-foreground placeholder:text-muted-foreground/30 outline-none disabled:opacity-40 caret-terminal-green"
                spellCheck={false}
                autoComplete="off"
                autoCorrect="off"
                autoCapitalize="off"
                data-ocid="repl.input"
                aria-label="REPL input"
              />
            </div>
          </div>
        </main>

        {/* Right: Environment panel (~30%) */}
        <aside className="w-64 xl:w-72 shrink-0 flex flex-col border-l border-border bg-card/20 hidden sm:flex">
          <EnvPanel
            bindings={envBindings}
            isLoading={isEnvLoading}
            isResetting={isResetting}
            onReset={handleReset}
          />
        </aside>
      </div>

      {/* Footer */}
      <footer className="shrink-0 border-t border-border px-4 py-2 flex items-center justify-between bg-card/30">
        <div className="font-mono text-xs text-muted-foreground/40">
          ↑↓ history · Enter evaluate · Ctrl+C clear
        </div>
        <div className="font-mono text-xs text-muted-foreground/40">
          © {new Date().getFullYear()}.{" "}
          <a
            href={`https://caffeine.ai?utm_source=caffeine-footer&utm_medium=referral&utm_content=${encodeURIComponent(window.location.hostname)}`}
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-terminal-green transition-colors"
          >
            Built with ♥ using caffeine.ai
          </a>
        </div>
      </footer>
    </div>
  );
}
