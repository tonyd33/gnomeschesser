export type Unit = "unit symbol";
export type Result<T, K> = (T extends Unit ? ["ok"] : ["ok", T]) | ["err", K];
