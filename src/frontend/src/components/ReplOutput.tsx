import { cn } from "@/lib/utils";

export type HistoryEntry =
  | { kind: "input"; text: string; id: number }
  | { kind: "output"; value: string; typeStr: string; id: number }
  | { kind: "error"; message: string; id: number }
  | { kind: "pending"; text: string; id: number }
  | { kind: "system"; message: string; id: number };

interface ReplOutputProps {
  entries: HistoryEntry[];
}

export function ReplOutput({ entries }: ReplOutputProps) {
  return (
    <div className="space-y-0.5">
      {entries.map((entry) => {
        switch (entry.kind) {
          case "input":
            return (
              <div
                key={entry.id}
                className="line-appear flex items-start gap-2 py-0.5"
              >
                <span className="text-terminal-prompt font-mono text-sm font-semibold shrink-0 text-glow-sm select-none">
                  &gt;
                </span>
                <span className="font-mono text-sm text-foreground/90 break-all">
                  {entry.text}
                </span>
              </div>
            );
          case "output":
            return (
              <div
                key={entry.id}
                className="line-appear flex items-start gap-2 py-0.5 pl-4"
              >
                <span className="font-mono text-sm">
                  <span className="text-terminal-green text-glow-sm font-medium">
                    {entry.value}
                  </span>
                  {entry.typeStr && (
                    <span className="text-terminal-type ml-1">
                      <span className="opacity-60"> : </span>
                      <span className="italic">{entry.typeStr}</span>
                    </span>
                  )}
                </span>
              </div>
            );
          case "error":
            return (
              <div
                key={entry.id}
                className="line-appear flex items-start gap-2 py-0.5 pl-4"
              >
                <span className="font-mono text-sm text-terminal-error">
                  <span className="opacity-70 mr-1">⚠</span>
                  {entry.message}
                </span>
              </div>
            );
          case "pending":
            return (
              <div key={entry.id} className="flex items-start gap-2 py-0.5">
                <span className="text-terminal-prompt font-mono text-sm font-semibold shrink-0 select-none">
                  &gt;
                </span>
                <span className="font-mono text-sm text-foreground/60 break-all">
                  {entry.text}
                </span>
              </div>
            );
          case "system":
            return (
              <div key={entry.id} className="line-appear py-0.5 pl-4">
                <span className="font-mono text-xs text-muted-foreground italic">
                  {entry.message}
                </span>
              </div>
            );
          default:
            return null;
        }
      })}
    </div>
  );
}

interface EmptyStateProps {
  className?: string;
}

export function ReplEmptyState({ className }: EmptyStateProps) {
  return (
    <div
      className={cn("flex flex-col items-start gap-1 py-2", className)}
      data-ocid="repl.empty_state"
    >
      <div className="font-mono text-sm text-muted-foreground">
        <span className="text-terminal-green text-glow-sm">Mini-ML</span>{" "}
        interpreter ready.
      </div>
      <div className="font-mono text-xs text-muted-foreground/60 mt-1">
        Type an expression and press Enter to evaluate.
      </div>
    </div>
  );
}
