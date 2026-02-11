import gleeunit
import gleeunit/should
import singleflight

pub fn main() {
  gleeunit.main()
}

// Test basic single flight functionality
pub fn basic_test() {
  let sf = singleflight.new()

  // Simple function that returns a constant
  let work_fn = fn() { 42 }

  let #(result1, first_caller1) = singleflight.do(sf, "test-key", work_fn)
  should.equal(result1, 42)
  should.equal(first_caller1, True)
}

// Test that calling with same key doesn't re-execute (when using cache)
pub fn cache_test() {
  let sf = singleflight.new()
  let work_fn = fn() { 100 }

  let #(result1, sf2, first_caller1) =
    singleflight.do_with_cache(sf, "cache-key", work_fn)
  should.equal(result1, 100)
  should.equal(first_caller1, True)

  // Second call should return cached result
  let work_fn2 = fn() { 999 }
  // Different function
  let #(result2, _sf3, first_caller2) =
    singleflight.do_with_cache(sf2, "cache-key", work_fn2)
  should.equal(result2, 100)
  // Should still be 100 from cache
  should.equal(first_caller2, False)
}

// Test that different keys work independently
pub fn different_keys_test() {
  let sf = singleflight.new()

  let work_fn1 = fn() { 1 }
  let work_fn2 = fn() { 2 }

  let #(result1, _) = singleflight.do(sf, "key1", work_fn1)
  let #(result2, _) = singleflight.do(sf, "key2", work_fn2)

  should.equal(result1, 1)
  should.equal(result2, 2)
}

// Test forget functionality
pub fn forget_test() {
  let sf = singleflight.new()
  let work_fn1 = fn() { 100 }

  let #(result1, sf2, first_caller1) =
    singleflight.do_with_cache(sf, "forget-key", work_fn1)
  should.equal(result1, 100)
  should.equal(first_caller1, True)

  // Forget the key
  let sf3 = singleflight.forget(sf2, "forget-key")

  // Now calling again should execute the function again
  let work_fn2 = fn() { 200 }
  let #(result2, _sf4, first_caller2) =
    singleflight.do_with_cache(sf3, "forget-key", work_fn2)
  should.equal(result2, 200)
  should.equal(first_caller2, True)
}
