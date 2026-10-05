import { registerPlugin } from '@capacitor/core';

const native = registerPlugin('IOSPerformance');
export const Performance = {
  configure: (options) => native.configure(options),
  start: (options) => native.start(options),
  mark: (options) => native.mark(options),
  end: (options) => native.end(options),
  snapshot: () => native.snapshot(),
  reset: () => native.reset(),
  exportJSON: async () => (await native.exportJSON()).value,
  exportCSV: async () => (await native.exportCSV()).value,
};
