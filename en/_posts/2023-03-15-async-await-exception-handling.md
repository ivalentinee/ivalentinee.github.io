---
layout: post
title:  "async/await exception handling"
date:   2023-03-15
categories: programming
uid: async-await-exception-handling
---

## Intro
All of a sudden I started writing NodeJS code about a year ago. Didn't want to, but there was no choice – code should cross-compile for both browser and server.

It turned out that async/await in JS is a complicated topic for many. And if most problematic cases are highlighted by TypeScript, this situation is correct by both JS and TS, but the code fails when it should not.

## Problem
Problem happens when trying to catch errors in async functions.

### Question
Two examples:
```js
// --- Example 1
async function something() {
// ...
  return await someOtherAsyncFunction();
// ...
```
```js
// --- Example 2
async function something() {
// ...
  return someOtherAsyncFunction();
// ...
```
Can you guess what's wrong here?

Even eslint marks example 1 code as incorrect. "Thank you eslint for that".

### Answer
Now here's some code which tells what's wrong with example 2:
```js
async function fail() {
  throw new Error('Ultimate failure');
}

await (async () => {
  try {
    return await fail();
  } catch (error) {
    console.log('The error was caught');
  }
})();

await (async () => {
  try {
    return fail();
  } catch (error) {
    console.log('The error was not caught');
  }
})();
```
`'The error was not caught'` won't be printed because the error is not caught in the second function.

### Explanation
To explain this I have to explain async/await a bit deeper (but not too much).

[Async/await](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function) is just a syntactic sugar for [promises](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) which on the other hand are just a syntactic sugar for callbacks. These two allows for asynchronous code to be written in "pseudo-synchronous" manner.

#### Async functions
Marking function as `async` allows to use `await` in function definition.

Aside from that, if async function returns non-promise, returned value is wrapped into a promise (with somethin like `Promise.resolve(value)`).\\
Example:
```js
async function returnNumber() {
  return 1;
}

console.log(returnNumber());

// Promise { 1 }
```

And, finally, if async function throws an error that error is automatically wrapped into a promise too (with something like `Promise.reject(exception)`).\\
Example:
```js
async function fail() {
  throw new Error('Ultimate failure');
}

console.log(fail());

// Promise { <rejected> Error: Ultimate failure }
```

#### Await and promise unwrapping
Await does promise unwrapping for other async-function returned values called with `await`:
```js
async function returnNumber() {
  return 1;
}

console.log(await returnNumber());

// 1
```

And if returned promise is rejected that exception is rethrown (and then re-wrapped with `Promise.reject` if not catched with try-catch):
```js
async function fail() {
  throw new Error('Ultimate failure');
}

console.log(await fail());

// console.log won't print anything, but 'Uncaught Error: Ultimate failure' will be displayed
```

### What's the problem and how to solve it?
So if the last (up the call stack) try-catch won't have `await` when calling probably-exception-throwing-async-function promise will be returned as-is (rejected) and try-catch won't get into `catch` block. Successfully passing try-catch exception will then be fired by the system.

And if unhandled exception in browser results in just a red line in dev-tools, server will have the entire NodeJS process down (well, if no wanky code like `process.on('uncaughtException', (error: Error) => { /* ... */ });` will be used) and if lucky will just be restarted (losing all the data).

How to avoid that? Try to return all async function results through `await` in try-catch blocks even if it looks unnecessary:
```js
try {
  const result = await fail();
  return result;
} catch (error) {
  logger.log(error);
  return undefined;
}

```
And call async function with `await` even if these functions do not return any actual value (`Promise<void>`):
```js
await fail();
```

Yes, excessive promise wrapping/unwrapping will cause more event loop cycles to pass results, but that tiny overhead will stabilize the system at code level significantly.

## Conclusion
It turned out, problematic code is usually written by developers that have almost no experience with NodeJS – those who write code for browser or write so little code that such async-related problems never occur.

Now I use this question (async/await with exceptions) on interviews to find out if applicant actually used NodeJS or just played with it.
