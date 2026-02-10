// SingleFlight implementation in Gleam
// Inspired by Go's golang.org/x/sync/singleflight package

import gleam/async.{Future, await, complete, make_future}
import gleam/dict
import gleam/list
import gleam/map
import gleam/io
import gleam/result

// We'll use a global registry approach since Gleam doesn't have mutable shared state
// like Go's sync.Map. This uses an Erlang/Elixir-style approach with a GenServer-like pattern.
// For simplicity, we'll implement a basic version using processes and message passing.

pub type SingleFlightRequest(value) {
  Execute(key: String, work_fn: fn() -> value)
  ExecuteAsync(key: String, work_fn: fn() -> Future(value))
}

pub type SingleFlightResponse(value) {
  Result(value: value, first_caller: Bool)
  Error(error: String)
}

// A process-based approach to implement singleflight
// Since Gleam runs on BEAM, we can use processes for coordination

// A registry process that manages ongoing requests
pub fn start_registry() -> Future(Int) {
  let #(future, completer) = make_future()
  spawn_registry_process(completer)
  future
}

fn spawn_registry_process(completer) -> Nil {
  let pid = erlang.spawn(fn() { registry_loop(map.new()) })
  complete(completer, pid)
}

fn registry_loop(requests: Map(String, Future(a))) -> Nil {
  receive {
    msg -> handle_registry_message_and_continue(msg, requests)
  }
}

fn handle_registry_message_and_continue(message, requests) -> Nil {
  let updated_requests = handle_registry_message(message, requests)
  registry_loop(updated_requests)
}

fn handle_registry_message(message, requests) -> Map(String, Future(a)) {
  case message {
    // For now, we'll implement a simplified version without process registry
    // Instead, let's create a simpler implementation using atoms for synchronization
    _ -> requests  // Return unchanged for now
  }
}

// Simplified implementation using a shared data structure approach
// Since Gleam doesn't support true shared mutable state, we'll implement
// a version that works within a single process context

pub type SingleFlightState(result) {
  SingleFlightState(
    ongoing_requests: Map(String, Future(result))
  )
}

/// Create a new SingleFlightState instance
pub fn new_state() -> SingleFlightState(a) {
  SingleFlightState(ongoing_requests: map.new())
}

/// Execute a function only once per key, returning the same result to all callers
/// This is a simplified synchronous version that works within a single process
pub fn do_sync(state: SingleFlightState(result), key: String, work_fn: fn() -> result) -> #(result, Bool, SingleFlightState(result)) {
  case map.get(state.ongoing_requests, key) {
    // There's already an ongoing request for this key - this shouldn't happen
    // in the sync version since everything executes immediately
    Some(_) -> panic("Should not have ongoing request in sync version")
    
    // No ongoing request, execute it
    None -> {
      let result = work_fn()
      #(result, True, state) // Return original state since no async operation
    }
  }
}

// For a true async version, we need to use Erlang/OTP processes
// Here's a better implementation using Erlang's ets (Erlang Term Storage) for shared state
// This requires using Erlang interop to achieve the shared state needed for singleflight

// The actual implementation will use a combination of futures and shared state
pub type SingleFlight(result) {
  SingleFlight
}

pub fn new() -> SingleFlight(a) {
  SingleFlight
}

/// Execute a function only once per key, returning the same result to all callers
/// This implementation uses a global ETS table to track ongoing requests
pub fn do(single_flight: SingleFlight(result), key: String, work_fn: fn() -> result) -> #(result, Bool) {
  // Using Erlang's ets (Erlang Term Storage) for global state management
  let table = get_or_create_ets_table()
  
  case ets_lookup(table, key) {
    // If there's already an ongoing request, wait for its result
    [future] -> #(
      await(cast_future(future)),
      False // Not the first caller
    )
    
    // No ongoing request, start one
    [] -> {
      let #(main_future, completer) = make_future()
      
      // Store the future in the ets table before executing work
      ets_insert_new(table, key, main_future)
      
      try {
        let result = work_fn()
        complete(completer, result)
        
        // Clean up the entry from the table
        ets_delete(table, key)
        
        #(result, True) // First caller
      } catch error {
        // Clean up on error too
        ets_delete(table, key)
        panic
      }
    }
  }
}

// Helper functions to interact with Erlang's ets
fn get_or_create_ets_table() -> Int {
  // Create a named ETS table for storing ongoing requests
  // Using erlang interop to access ETS functionality
  let table_name = "singleflight"
  let options = [set, public, named_table]
  erlang:spawn(fn() { ets:new(table_name, options) })
  // For now, returning a placeholder; in practice we'd need to manage this differently
  1
}

fn ets_lookup(table_id: Int, key: String) -> List(a) {
  // Look up a value in the ETS table
  // Using erlang interop
  erlang:ets:lookup(table_id, key)
}

fn ets_insert_new(table_id: Int, key: String, value: a) -> Bool {
  // Insert a new value into the ETS table
  // Using erlang interop
  erlang:ets:insert_new(table_id, #(key, value))
}

fn ets_delete(table_id: Int, key: String) -> Nil {
  // Delete a value from the ETS table
  // Using erlang interop
  erlang:ets:delete(table_id, key)
}

fn cast_future(future: Future(a)) -> Future(a) {
  // Direct cast since types match
  future
}

// Async version of do function
pub fn do_async(single_flight: SingleFlight(result), key: String, work_fn: fn() -> Future(result)) -> Future(result) {
  let table = get_or_create_ets_table()
  
  case ets_lookup(table, key) {
    // If there's already an ongoing request, return its future
    [future] -> cast_future(future)
    
    // No ongoing request, start one
    [] -> {
      let #(main_future, completer) = make_future()
      
      // Store the future in the ets table before executing work
      ets_insert_new(table, key, main_future)
      
      // Execute the async work function
      erlang.spawn(fn() {
        let result_future = work_fn()
        let result = await(result_future)
        complete(completer, result)
        
        // Clean up the entry from the table
        ets_delete(table, key)
      })
      
      main_future
    }
  }
}