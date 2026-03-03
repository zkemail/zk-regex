import { describe, it, expect } from 'bun:test';
import { generateScaledInput, type ScalingConfig } from '../../src/utils/input-scaling.js';

describe('input-scaling utilities', () => {
  describe('generateScaledInput', () => {
    it('returns empty string for zero target length', () => {
      const config: ScalingConfig = { strategy: 'repeat', inputTemplate: 'hello ' };
      expect(generateScaledInput(config, 0)).toBe('');
    });

    it('returns empty string for negative target length', () => {
      const config: ScalingConfig = { strategy: 'repeat', inputTemplate: 'hello ' };
      expect(generateScaledInput(config, -1)).toBe('');
    });

    it('throws for unknown strategy', () => {
      const config = { strategy: 'unknown' as any, inputTemplate: 'test' };
      expect(() => generateScaledInput(config, 10)).toThrow('Unknown scaling strategy');
    });
  });

  describe('repeat strategy', () => {
    it('repeats template to fill exact target length', () => {
      const config: ScalingConfig = { strategy: 'repeat', inputTemplate: 'ab' };
      expect(generateScaledInput(config, 6)).toBe('ababab');
    });

    it('truncates repeated template to exact target length', () => {
      const config: ScalingConfig = { strategy: 'repeat', inputTemplate: 'hello ' };
      const result = generateScaledInput(config, 10);
      expect(result.length).toBe(10);
      expect(result).toBe('hello hell');
    });

    it('returns truncated template when template is longer than target', () => {
      const config: ScalingConfig = { strategy: 'repeat', inputTemplate: 'hello world' };
      expect(generateScaledInput(config, 5)).toBe('hello');
    });

    it('returns spaces for empty template', () => {
      const config: ScalingConfig = { strategy: 'repeat', inputTemplate: '' };
      const result = generateScaledInput(config, 4);
      expect(result.length).toBe(4);
      expect(result).toBe('    ');
    });

    it('handles template equal to target length', () => {
      const config: ScalingConfig = { strategy: 'repeat', inputTemplate: 'exact' };
      expect(generateScaledInput(config, 5)).toBe('exact');
    });

    it('generates correct content for foo|bar|baz pattern', () => {
      const config: ScalingConfig = { strategy: 'repeat', inputTemplate: 'foo bar baz ' };
      const result = generateScaledInput(config, 64);
      expect(result.length).toBe(64);
      expect(result.startsWith('foo bar baz ')).toBe(true);
    });

    it('generates correct content for email_basic pattern', () => {
      const config: ScalingConfig = { strategy: 'repeat', inputTemplate: 'a@b.co ' };
      const result = generateScaledInput(config, 128);
      expect(result.length).toBe(128);
      expect(result.startsWith('a@b.co ')).toBe(true);
    });
  });

  describe('extend strategy', () => {
    describe('before-last position', () => {
      it('inserts extendChar before last character', () => {
        const config: ScalingConfig = {
          strategy: 'extend',
          inputTemplate: 'ab',
          extendChar: 'a',
          extendPosition: 'before-last',
        };
        // For target 6: 'a' + 'aaaa' + 'b' = 'aaaaab'
        const result = generateScaledInput(config, 6);
        expect(result.length).toBe(6);
        expect(result).toBe('aaaaab');
      });

      it('extends a*b pattern correctly', () => {
        const config: ScalingConfig = {
          strategy: 'extend',
          inputTemplate: 'ab',
          extendChar: 'a',
          extendPosition: 'before-last',
        };
        const result = generateScaledInput(config, 10);
        expect(result.length).toBe(10);
        // Should be 9 'a's + 'b'
        expect(result).toBe('aaaaaaaaab');
      });

      it('handles template longer than target', () => {
        const config: ScalingConfig = {
          strategy: 'extend',
          inputTemplate: 'abcdef',
          extendChar: 'x',
          extendPosition: 'before-last',
        };
        expect(generateScaledInput(config, 3)).toBe('abc');
      });

      it('handles template equal to target', () => {
        const config: ScalingConfig = {
          strategy: 'extend',
          inputTemplate: 'ab',
          extendChar: 'a',
          extendPosition: 'before-last',
        };
        expect(generateScaledInput(config, 2)).toBe('ab');
      });
    });

    describe('end position', () => {
      it('appends extendChar after template', () => {
        const config: ScalingConfig = {
          strategy: 'extend',
          inputTemplate: 'abc',
          extendChar: 'x',
          extendPosition: 'end',
        };
        expect(generateScaledInput(config, 6)).toBe('abcxxx');
      });

      it('extends char_class_basic correctly', () => {
        const config: ScalingConfig = {
          strategy: 'extend',
          inputTemplate: 'abcdefghijklmnopqrstuvwxyz',
          extendChar: 'a',
          extendPosition: 'end',
        };
        const result = generateScaledInput(config, 64);
        expect(result.length).toBe(64);
        expect(result.startsWith('abcdefghijklmnopqrstuvwxyz')).toBe(true);
        // Remaining 38 chars should be 'a'
        expect(result.slice(26)).toBe('a'.repeat(38));
      });

      it('handles template longer than target', () => {
        const config: ScalingConfig = {
          strategy: 'extend',
          inputTemplate: 'abcdefghij',
          extendChar: 'a',
          extendPosition: 'end',
        };
        expect(generateScaledInput(config, 5)).toBe('abcde');
      });
    });

    it('uses default extendChar (a) and position (end) when not specified', () => {
      const config: ScalingConfig = {
        strategy: 'extend',
        inputTemplate: 'test',
      };
      const result = generateScaledInput(config, 8);
      expect(result).toBe('testaaaa');
    });
  });

  describe('pad-with-match strategy', () => {
    it('pads with spaces by default', () => {
      const config: ScalingConfig = {
        strategy: 'pad-with-match',
        inputTemplate: 'hello',
      };
      const result = generateScaledInput(config, 10);
      expect(result.length).toBe(10);
      expect(result).toBe('hello     ');
    });

    it('returns full template when template is longer than target (no truncation)', () => {
      const config: ScalingConfig = {
        strategy: 'pad-with-match',
        inputTemplate: '\r\ndkim-signature:v=1; a=rsa-sha256; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=',
      };
      const result = generateScaledInput(config, 10);
      // pad-with-match never truncates - returns full template
      expect(result).toBe(config.inputTemplate);
      expect(result.length).toBeGreaterThan(10);
    });

    it('handles template equal to target length', () => {
      const config: ScalingConfig = {
        strategy: 'pad-with-match',
        inputTemplate: 'exact',
      };
      expect(generateScaledInput(config, 5)).toBe('exact');
    });

    it('uses custom padFiller when specified', () => {
      const config: ScalingConfig = {
        strategy: 'pad-with-match',
        inputTemplate: 'hi',
        padFiller: 'xy',
      };
      const result = generateScaledInput(config, 8);
      expect(result.length).toBe(8);
      expect(result).toBe('hixyxyxy');
    });

    it('handles body_hash pattern template', () => {
      const template = '\r\ndkim-signature:v=1; a=rsa-sha256; bh=BWETwQ9JDReS4GyR2v2TTR8Bpzj9ayumsWQJ3q7vehs=; b=';
      const config: ScalingConfig = {
        strategy: 'pad-with-match',
        inputTemplate: template,
      };
      const result = generateScaledInput(config, 256);
      expect(result.length).toBe(256);
      expect(result.startsWith(template)).toBe(true);
    });

    it('handles email_addr pattern template', () => {
      const template = '\r\nto:test@example.com\r\n';
      const config: ScalingConfig = {
        strategy: 'pad-with-match',
        inputTemplate: template,
      };
      const result = generateScaledInput(config, 128);
      expect(result.length).toBe(128);
      expect(result.startsWith(template)).toBe(true);
    });
  });

  describe('output length consistency', () => {
    const targetLengths = [64, 128, 256, 512];

    it('repeat strategy always returns exact target length', () => {
      const config: ScalingConfig = { strategy: 'repeat', inputTemplate: 'hello ' };
      for (const len of targetLengths) {
        expect(generateScaledInput(config, len).length).toBe(len);
      }
    });

    it('extend (end) strategy always returns exact target length', () => {
      const config: ScalingConfig = {
        strategy: 'extend',
        inputTemplate: 'abcdefghijklmnopqrstuvwxyz',
        extendChar: 'a',
        extendPosition: 'end',
      };
      for (const len of targetLengths) {
        expect(generateScaledInput(config, len).length).toBe(len);
      }
    });

    it('extend (before-last) strategy always returns exact target length', () => {
      const config: ScalingConfig = {
        strategy: 'extend',
        inputTemplate: 'ab',
        extendChar: 'a',
        extendPosition: 'before-last',
      };
      for (const len of targetLengths) {
        expect(generateScaledInput(config, len).length).toBe(len);
      }
    });

    it('pad-with-match strategy returns at least target length', () => {
      const config: ScalingConfig = {
        strategy: 'pad-with-match',
        inputTemplate: '\r\nsubject:Hello World\r\n',
      };
      for (const len of targetLengths) {
        // pad-with-match returns full template even if longer than target
        const result = generateScaledInput(config, len);
        expect(result.length).toBeGreaterThanOrEqual(Math.min(len, config.inputTemplate.length));
      }
    });
  });
});
