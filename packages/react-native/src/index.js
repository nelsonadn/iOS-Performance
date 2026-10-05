import { NativeModules, Platform } from 'react-native';

const native = NativeModules.IOSPerformance;
function bridge() {
  if (Platform.OS !== 'ios' || !native) throw new Error('IOSPerformanceCore is available only on iOS after CocoaPods installation.');
  return native;
}
export const Performance = {
  configure: (options = {}) => bridge().configure(options),
  start: (name) => bridge().start({ name }),
  mark: (name, category) => bridge().mark({ name, category }),
  end: (name) => bridge().end({ name }),
  snapshot: () => bridge().snapshot(),
  reset: () => bridge().reset(),
  exportJSON: () => bridge().exportJSON(),
  exportCSV: () => bridge().exportCSV(),
};
