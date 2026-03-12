import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Skeleton } from "@/components/ui/skeleton";
import { RotateCcw } from "lucide-react";
import type { EnvBinding } from "../hooks/useBackend";

interface EnvPanelProps {
  bindings: EnvBinding[];
  isLoading: boolean;
  isResetting: boolean;
  onReset: () => void;
}

export function EnvPanel({
  bindings,
  isLoading,
  isResetting,
  onReset,
}: EnvPanelProps) {
  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="px-4 py-3 border-b border-border">
        <h2 className="font-mono text-xs font-semibold text-muted-foreground uppercase tracking-widest">
          Environment
        </h2>
      </div>

      {/* Bindings list */}
      <ScrollArea className="flex-1 min-h-0">
        <div className="p-3 space-y-0">
          {isLoading ? (
            <div className="space-y-2 p-1" data-ocid="env.loading_state">
              {[1, 2, 3].map((i) => (
                <Skeleton
                  key={i}
                  className="h-8 w-full rounded-sm bg-muted/30"
                />
              ))}
            </div>
          ) : bindings.length === 0 ? (
            <div className="px-1 py-4 text-center" data-ocid="env.empty_state">
              <div className="font-mono text-xs text-muted-foreground/50 italic">
                No bindings yet
              </div>
            </div>
          ) : (
            <div className="space-y-px">
              {bindings.map((binding, index) => (
                <div
                  key={`${binding.name}-${index}`}
                  className="group px-2 py-1.5 rounded-sm hover:bg-secondary/50 transition-colors"
                  data-ocid={`env.item.${index + 1}`}
                >
                  <div className="font-mono text-xs leading-relaxed">
                    <span className="text-terminal-green text-glow-sm font-medium">
                      {binding.name}
                    </span>
                    <span className="text-muted-foreground/60"> : </span>
                    <span className="text-terminal-type italic">
                      {binding.typeStr}
                    </span>
                  </div>
                  {binding.valueStr && binding.valueStr !== binding.name && (
                    <div className="font-mono text-xs text-muted-foreground/50 pl-2 truncate">
                      = {binding.valueStr}
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </ScrollArea>

      {/* Reset button */}
      <div className="p-3 border-t border-border">
        <Button
          variant="outline"
          size="sm"
          onClick={onReset}
          disabled={isResetting}
          className="w-full font-mono text-xs border-border text-muted-foreground hover:text-terminal-error hover:border-terminal-error/50 hover:bg-terminal-error/5 transition-all gap-2"
          data-ocid="env.reset_button"
        >
          <RotateCcw
            className={`h-3 w-3 ${isResetting ? "animate-spin" : ""}`}
          />
          {isResetting ? "Resetting..." : "Reset Session"}
        </Button>
      </div>
    </div>
  );
}
