/**
 * Input scaling utilities for benchmark input generation.
 *
 * Generates regex-matching content that fills the target input length,
 * so benchmarks measure actual regex work instead of zero-padded overhead.
 */

/**
 * Strategy for scaling input content to fill target length.
 *
 * - 'repeat': Repeat inputTemplate to fill targetLength
 * - 'extend': Grow a variable-length match portion (e.g., 'a*b' -> 'aaa...ab')
 * - 'pad-with-match': Place template at start, fill rest with safe filler
 */
export type ScalingStrategy = 'repeat' | 'extend' | 'pad-with-match';

/**
 * Position for character extension in 'extend' strategy.
 *
 * - 'before-last': Insert extendChar before the last character of the template
 * - 'end': Append extendChar after the template
 */
export type ExtendPosition = 'before-last' | 'end';

export interface ScalingConfig {
  strategy: ScalingStrategy;
  inputTemplate: string;
  extendChar?: string;
  extendPosition?: ExtendPosition;
  padFiller?: string;
}

/**
 * Generate a regex-matching input string of exactly targetLength bytes.
 */
export function generateScaledInput(
  config: ScalingConfig,
  targetLength: number
): string {
  if (targetLength <= 0) return '';

  switch (config.strategy) {
    case 'repeat':
      return generateRepeat(config.inputTemplate, targetLength);
    case 'extend':
      return generateExtend(config, targetLength);
    case 'pad-with-match':
      return generatePadWithMatch(config, targetLength);
    default:
      throw new Error(`Unknown scaling strategy: ${config.strategy}`);
  }
}

/**
 * Repeat strategy: repeat the template to fill targetLength.
 */
function generateRepeat(template: string, targetLength: number): string {
  if (template.length === 0) return ' '.repeat(targetLength);
  if (template.length >= targetLength) return template.slice(0, targetLength);
  const repeats = Math.ceil(targetLength / template.length);
  return template.repeat(repeats).slice(0, targetLength);
}

/**
 * Extend strategy: grow a variable-length match portion.
 *
 * For 'before-last': template is e.g. "ab", extendChar is "a"
 *   -> "aaa...ab" (insert 'a's before the last char 'b')
 *
 * For 'end': template is e.g. "abcdef", extendChar is "a"
 *   -> "abcdefaaa..." (append 'a's after the template)
 */
function generateExtend(config: ScalingConfig, targetLength: number): string {
  const { inputTemplate, extendChar = 'a', extendPosition = 'end' } = config;

  if (inputTemplate.length >= targetLength) {
    return inputTemplate.slice(0, targetLength);
  }

  const remaining = targetLength - inputTemplate.length;

  if (extendPosition === 'before-last' && inputTemplate.length > 0) {
    const prefix = inputTemplate.slice(0, -1);
    const lastChar = inputTemplate.slice(-1);
    const padding = extendChar.repeat(remaining);
    const result = prefix + padding + lastChar;
    return result.slice(0, targetLength);
  }

  // 'end' position
  return inputTemplate + extendChar.repeat(remaining);
}

/**
 * Pad-with-match strategy: place template at start, fill rest with safe filler.
 *
 * Used for anchored patterns like email headers where the template can't be repeated.
 * The filler is spaces by default (safe for most patterns).
 *
 * When the template is longer than targetLength, the full template is returned
 * without truncation - these templates represent the minimum viable match and
 * truncating would break the regex. The circuit capacity (maxHaystackBytes)
 * is always large enough to hold the full template.
 */
function generatePadWithMatch(config: ScalingConfig, targetLength: number): string {
  const { inputTemplate, padFiller = ' ' } = config;

  if (inputTemplate.length >= targetLength) {
    // Return full template - never truncate anchored patterns
    return inputTemplate;
  }

  const remaining = targetLength - inputTemplate.length;
  const filler = padFiller.repeat(Math.ceil(remaining / padFiller.length)).slice(0, remaining);
  return inputTemplate + filler;
}
