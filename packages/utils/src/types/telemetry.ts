export const TelemetryType = {
  Execute: 'Execute',
} as const;

export type TelemetryType = (typeof TelemetryType)[keyof typeof TelemetryType];

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Telemetry<T = any> = {
  from: string;
  status: number;
  type: TelemetryType;
  message: string;
  data: T;
  timestamp: number;
};
