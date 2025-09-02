import { LogLevel } from './types.js';

/**
 * Structured logger with different log levels
 */
export class Logger {
  constructor(private readonly minLevel: LogLevel = LogLevel.Info) {}

  /**
   * Log a message with the specified level
   */
  log(level: LogLevel, message: string, context?: Record<string, unknown>): void {
    if (level < this.minLevel) {
      return;
    }

    const timestamp = new Date().toISOString();
    const levelStr = LogLevel[level].toUpperCase();
    const contextStr = context ? ` ${JSON.stringify(context, null, 2)}` : '';
    
    console.log(`[${timestamp}] ${levelStr}: ${message}${contextStr}`);
  }

  debug(message: string, context?: Record<string, unknown>): void {
    this.log(LogLevel.Debug, message, context);
  }

  info(message: string, context?: Record<string, unknown>): void {
    this.log(LogLevel.Info, message, context);
  }

  warn(message: string, context?: Record<string, unknown>): void {
    this.log(LogLevel.Warn, message, context);
  }

  error(message: string, context?: Record<string, unknown>): void {
    this.log(LogLevel.Error, message, context);
  }
}

export const logger = new Logger();