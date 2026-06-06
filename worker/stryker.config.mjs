/** @type {import('@stryker-mutator/api/core').PartialStrykerOptions} */
export default {
  packageManager: 'npm',
  reporters: ['html', 'clear-text', 'progress'],
  testRunner: 'vitest',
  coverageAnalysis: 'perTest',
  mutate: ['src/index.js'],
  vitest: {
    configFile: 'vitest.config.js',
  },
  thresholds: {
    high: 80,
    low: 60,
    break: 50,
  },
};
