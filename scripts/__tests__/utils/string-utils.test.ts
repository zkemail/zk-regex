/**
 * Tests for string utility functions
 */

import { toPascalCase, toSnakeCase, capitalize } from '../../utils/string-utils.js';

describe('String Utilities', () => {
  describe('toPascalCase', () => {
    test('converts snake_case correctly', () => {
      expect(toPascalCase('email_address')).toBe('EmailAddress');
      expect(toPascalCase('simple')).toBe('Simple');
      expect(toPascalCase('from_all')).toBe('FromAll');
      expect(toPascalCase('body_hash')).toBe('BodyHash');
    });

    test('converts kebab-case correctly', () => {
      expect(toPascalCase('email-address')).toBe('EmailAddress');
      expect(toPascalCase('message-id')).toBe('MessageId');
    });

    test('handles mixed separators', () => {
      expect(toPascalCase('email_address-test')).toBe('EmailAddressTest');
    });

    test('handles single words', () => {
      expect(toPascalCase('simple')).toBe('Simple');
      expect(toPascalCase('test')).toBe('Test');
    });

    test('handles empty string', () => {
      expect(toPascalCase('')).toBe('');
    });

    test('handles multiple consecutive separators', () => {
      expect(toPascalCase('email__address')).toBe('EmailAddress');
      expect(toPascalCase('email--address')).toBe('EmailAddress');
    });
  });

  describe('toSnakeCase', () => {
    test('converts PascalCase correctly', () => {
      expect(toSnakeCase('EmailAddress')).toBe('email_address');
      expect(toSnakeCase('SimpleRegex')).toBe('simple_regex');
      expect(toSnakeCase('BodyHash')).toBe('body_hash');
    });

    test('converts camelCase correctly', () => {
      expect(toSnakeCase('emailAddress')).toBe('email_address');
      expect(toSnakeCase('messageId')).toBe('message_id');
    });

    test('handles numbers', () => {
      expect(toSnakeCase('Html2Text')).toBe('html2_text');
      expect(toSnakeCase('Test123ABC')).toBe('test123_a_b_c');
    });

    test('handles single words', () => {
      expect(toSnakeCase('Simple')).toBe('simple');
      expect(toSnakeCase('test')).toBe('test');
    });

    test('handles empty string', () => {
      expect(toSnakeCase('')).toBe('');
    });

    test('handles already snake_case', () => {
      expect(toSnakeCase('already_snake_case')).toBe('already_snake_case');
    });
  });

  describe('capitalize', () => {
    test('capitalizes first letter', () => {
      expect(capitalize('hello')).toBe('Hello');
      expect(capitalize('world')).toBe('World');
    });

    test('handles single character', () => {
      expect(capitalize('a')).toBe('A');
    });

    test('handles empty string', () => {
      expect(capitalize('')).toBe('');
    });

    test('leaves rest of string unchanged', () => {
      expect(capitalize('hELLO')).toBe('HELLO');
      expect(capitalize('tEST')).toBe('TEST');
    });
  });
});