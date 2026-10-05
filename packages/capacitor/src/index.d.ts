export interface PerformanceResult {
  name: string;
  startTimestamp: string;
  endTimestamp: string;
  durationMs: number;
  marks: Array<{ name: string; offsetMs: number; category: string }>;
  metrics: Record<string, number | string | null>;
  applicationStateStart: string;
  applicationStateEnd: string;
  metadata: Record<string, string>;
}
export interface PerformanceConfiguration {
  samplingIntervalMilliseconds?: 50 | 100 | 250 | 500 | 1000;
  consoleLoggingEnabled?: boolean;
}
export declare const Performance: {
  configure(options?: PerformanceConfiguration): Promise<void>;
  start(options: { name: string }): Promise<void>;
  mark(options: { name: string; category?: string }): Promise<void>;
  end(options: { name: string }): Promise<PerformanceResult>;
  snapshot(): Promise<{ activeSessions: string[]; completedResults: PerformanceResult[] }>;
  reset(): Promise<void>;
  exportJSON(): Promise<string>;
  exportCSV(): Promise<string>;
};
