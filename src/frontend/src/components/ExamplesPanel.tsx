import { cn } from "@/lib/utils";
import { ChevronDown, ChevronRight } from "lucide-react";
import { useState } from "react";

const EXAMPLES = [
  { label: "Arithmetic", expr: "1 + 2" },
  { label: "Lambda", expr: "fun x -> x * x" },
  { label: "Let binding", expr: "let double = fun x -> x * 2" },
  {
    label: "Recursion",
    expr: "let rec fact = fun n -> if n = 0 then 1 else n * fact (n - 1) in fact 5",
  },
  { label: "Tuple", expr: '(1, true, "hello")' },
  { label: "Fst", expr: "fst (42, false)" },
];

interface ExamplesPanelProps {
  onSelect: (expr: string) => void;
}

export function ExamplesPanel({ onSelect }: ExamplesPanelProps) {
  const [open, setOpen] = useState(false);

  return (
    <div className="border-t border-border">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="w-full flex items-center gap-2 px-4 py-2 text-muted-foreground/60 hover:text-muted-foreground transition-colors"
        aria-expanded={open}
      >
        {open ? (
          <ChevronDown className="h-3 w-3" />
        ) : (
          <ChevronRight className="h-3 w-3" />
        )}
        <span className="font-mono text-xs uppercase tracking-widest">
          Examples
        </span>
      </button>

      <div
        className={cn(
          "overflow-hidden transition-all duration-200",
          open ? "max-h-64" : "max-h-0",
        )}
      >
        <div className="px-4 pb-3 grid grid-cols-2 gap-1 sm:grid-cols-3">
          {EXAMPLES.map((ex) => (
            <button
              key={ex.label}
              type="button"
              onClick={() => onSelect(ex.expr)}
              className="text-left px-2 py-1.5 rounded-sm border border-border/50 hover:border-terminal-green/40 hover:bg-secondary/50 transition-all group"
            >
              <div className="font-mono text-xs text-muted-foreground group-hover:text-terminal-green transition-colors truncate">
                {ex.expr}
              </div>
              <div className="font-mono text-xs text-muted-foreground/40 mt-0.5">
                {ex.label}
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
