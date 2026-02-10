// SingleFlight implementation in Gleam
// Inspired by Go's golang.org/x/sync/singleflight package
//
// Note: This is a simplified implementation for demonstration purposes.
// It provides a caching mechanism within a single process but does NOT prevent
// concurrent execution across multiple processes or concurrent function calls.
// A production implementation would require external Erlang FFI functions
// to properly interact with ETS tables and process management for true
// cross-process deduplication.

import gleam/dict.{type Dict}

/// Represents the state for singleflight operations
/// In a real implementation, this would use ETS or a GenServer for shared state
pub type SingleFlight(result) {
  SingleFlight(ongoing: Dict(String, result))
}

/// Create a new SingleFlight instance
pub fn new() -> SingleFlight(a) {
  SingleFlight(ongoing: dict.new())
}

/// Execute a function for a given key
/// 
/// Note: This does NOT cache results. Each call will execute work_fn.
/// Use `do_with_cache` if you want to cache results.
/// 
/// Returns a tuple of (result, is_first_caller)
/// - result: The result of the work function
/// - is_first_caller: True if no cached result exists, False otherwise
pub fn do(
  single_flight: SingleFlight(result),
  key: String,
  work_fn: fn() -> result,
) -> #(result, Bool) {
  case dict.get(single_flight.ongoing, key) {
    // There's already a cached result for this key
    Ok(cached_result) -> #(cached_result, False)

    // No cached result, execute the work function
    Error(_) -> {
      let result = work_fn()
      #(result, True)
    }
  }
}

/// Execute a function and store the result for future calls with the same key
/// Returns a tuple of (result, updated_state, is_first_caller)
pub fn do_with_cache(
  single_flight: SingleFlight(result),
  key: String,
  work_fn: fn() -> result,
) -> #(result, SingleFlight(result), Bool) {
  case dict.get(single_flight.ongoing, key) {
    // There's already a cached result for this key
    Ok(cached_result) -> #(cached_result, single_flight, False)

    // No cached result, execute the work function and cache it
    Error(_) -> {
      let result = work_fn()
      let updated_state =
        SingleFlight(ongoing: dict.insert(single_flight.ongoing, key, result))
      #(result, updated_state, True)
    }
  }
}

/// Forget a key, removing it from the cache
pub fn forget(
  single_flight: SingleFlight(result),
  key: String,
) -> SingleFlight(result) {
  SingleFlight(ongoing: dict.delete(single_flight.ongoing, key))
}
