# benchmark_restore_summary.exs

# Mock data generation
stats = Enum.map(1..1000, fn i ->
  %{
    count: i,
    total_size: i * 1024,
    runtime_ms: i,
    label: "Step #{i}"
  }
end)

# Original implementation
original = fn stats ->
  total_count = Enum.reduce(stats, 0, fn stat, acc -> acc + stat.count end)
  total_size = Enum.reduce(stats, 0, fn stat, acc -> acc + stat.total_size end)
  total_time = Enum.reduce(stats, 0, fn stat, acc -> acc + stat.runtime_ms end)
  {total_count, total_size, total_time}
end

# Optimized implementation
optimized = fn stats ->
  Enum.reduce(stats, {0, 0, 0}, fn stat, {count, size, time} ->
    {count + stat.count, size + stat.total_size, time + stat.runtime_ms}
  end)
end

# Simple benchmarking helper
benchmark = fn name, func, data, iterations ->
  IO.puts("Benchmarking #{name} (#{iterations} iterations)...")
  start = System.monotonic_time()
  Enum.each(1..iterations, fn _ -> func.(data) end)
  finish = System.monotonic_time()

  diff = System.convert_time_unit(finish - start, :native, :microsecond)
  IO.puts("#{name} took #{diff} microseconds total, average #{diff / iterations} microseconds/call")
  diff
end

iterations = 10_000
original_time = benchmark.("Original", original, stats, iterations)
optimized_time = benchmark.("Optimized", optimized, stats, iterations)

improvement = (original_time - optimized_time) / original_time * 100
IO.puts("\nImprovement: #{Float.round(improvement, 2)}%")
