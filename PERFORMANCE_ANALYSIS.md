# Theoretical Performance Analysis: Optimizing `display_summary` in `Vault.Commands.Restore`

## Current Implementation

The current implementation of `display_summary` in `lib/vault/commands/restore.ex` calculates three aggregate values from the `stats` list:

```elixir
total_count = Enum.reduce(stats, 0, fn stat, acc -> acc + stat.count end)
total_size = Enum.reduce(stats, 0, fn stat, acc -> acc + stat.total_size end)
total_time = Enum.reduce(stats, 0, fn stat, acc -> acc + stat.runtime_ms end)
```

### Inefficiency Details

1.  **Redundant List Traversals**: The `stats` list is iterated three times. For a list of size $n$, this results in $3n$ iterations.
2.  **Multiple Function Applications**: There are $3n$ function calls (one for each element in each `Enum.reduce`).
3.  **CPU Overhead**: Each traversal involves fetching the list head and moving to the next element, which adds up as $n$ increases.

## Optimized Implementation

The proposed optimization uses a single `Enum.reduce` to calculate all three values simultaneously:

```elixir
{total_count, total_size, total_time} =
  Enum.reduce(stats, {0, 0, 0}, fn stat, {count, size, time} ->
    {count + stat.count, size + stat.total_size, time + stat.runtime_ms}
  end)
```

### Expected Improvements

1.  **Reduced Iterations**: The list is traversed exactly once. For a list of size $n$, this is $n$ iterations instead of $3n$ ($66.7\%$ reduction in traversals).
2.  **Fewer Function Applications**: Only $n$ function calls are made instead of $3n$ ($66.7\%$ reduction in function call overhead).
3.  **Memory Locality**: Accessing the list elements once improves cache locality, although this is usually secondary in high-level languages like Elixir compared to the reduction in iterations and function calls.

## Conclusion

While the `stats` list in this specific tool (a backup/restore CLI) is likely to be small (dozens of entries), reducing the O(n) operations from $3n$ to $n$ is a standard best practice that improves both CPU efficiency and code clarity.
