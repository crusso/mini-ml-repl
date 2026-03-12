import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useActor } from "./useActor";

export type EnvBinding = {
  name: string;
  typeStr: string;
  valueStr: string;
};

export type EvalResult =
  | { __kind__: "ok"; ok: { value: string; typeStr: string } }
  | { __kind__: "err"; err: string };

export function useGetEnv() {
  const { actor, isFetching } = useActor();
  return useQuery({
    queryKey: ["env"] as const,
    queryFn: async (): Promise<EnvBinding[]> => {
      if (!actor) return [];
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const result = await (actor.getEnv() as unknown as Promise<any[]>);
      return result.map((item: unknown) => {
        if (Array.isArray(item)) {
          // DID returns [string, string] tuples: [name, typeStr]
          return {
            name: item[0] as string,
            typeStr: item[1] as string,
            valueStr: "",
          };
        }
        const obj = item as { name: string; typeStr: string; valueStr: string };
        return {
          name: obj.name,
          typeStr: obj.typeStr,
          valueStr: obj.valueStr ?? "",
        };
      });
    },
    enabled: !!actor && !isFetching,
  });
}

export function useEvaluate() {
  const { actor } = useActor();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (input: string): Promise<EvalResult> => {
      if (!actor) throw new Error("Actor not ready");
      return actor.evaluate(input);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["env"] });
    },
  });
}

export function useReset() {
  const { actor } = useActor();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async () => {
      if (!actor) throw new Error("Actor not ready");
      await actor.reset();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["env"] });
    },
  });
}
