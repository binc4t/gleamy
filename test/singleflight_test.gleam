import gleam/async.{await, make_future, complete}
import gleam/io
import gleam/test.{assert}
import gleam/list
import src/singleflight.{SingleFlight, new, do, do_async}

// Test the SingleFlight implementation
pub fn test_single_flight_basic() {
  let sf = new()
  
  // Simple function that returns a constant
  let work_fn = fn() { 42 }
  
  let #(result1, first_caller1) = do(sf, "test-key", work_fn)
  assert result1 == 42
  assert first_caller1 == True
  
  io.println("Basic single flight test passed!")
}

// Test concurrent access
pub fn test_concurrent_access() {
  let sf = new()
  
  // Function that takes some time to execute
  let slow_work_fn = fn() {
    // Simulate some work
    erlang:timer:sleep(100)
    100
  }
  
  // Call the same function twice with the same key
  // The second call should wait for the first to complete
  let #(result1, first_caller1) = do(sf, "slow-key", slow_work_fn)
  let #(result2, first_caller2) = do(sf, "slow-key", slow_work_fn)
  
  assert result1 == result2
  assert result1 == 100
  assert first_caller1 == True
  assert first_caller2 == False
  
  io.println("Concurrent access test passed!")
}

// Test async version
pub fn test_async_single_flight() {
  let sf = new()
  
  // Async function that returns a future
  let async_work_fn = fn() {
    let #(future, completer) = make_future()
    // Simulate async work
    erlang.spawn(fn() {
      erlang:timer:sleep(50)
      complete(completer, 200)
    })
    future
  }
  
  let future1 = do_async(sf, "async-key", async_work_fn)
  let future2 = do_async(sf, "async-key", async_work_fn)  // Same key
  
  let result1 = await(future1)
  let result2 = await(future2)
  
  assert result1 == result2
  assert result1 == 200
  
  io.println("Async single flight test passed!")
}

// Test different keys work independently
pub fn test_different_keys_independent() {
  let sf = new()
  
  let work_fn1 = fn() { 1 }
  let work_fn2 = fn() { 2 }
  
  let #(result1, _) = do(sf, "key1", work_fn1)
  let #(result2, _) = do(sf, "key2", work_fn2)
  
  assert result1 == 1
  assert result2 == 2
  
  io.println("Different keys independent test passed!")
}