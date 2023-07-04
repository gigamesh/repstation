const seconds = 10;
const decayRate = 0.01; // 1% per second
const initialAmount = 1000;

const decayedAmount = initialAmount * 2 ** (seconds * Math.log2(1 - decayRate));

console.log({ decayedAmount });
