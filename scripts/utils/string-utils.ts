/**
 * String utility functions for case conversions and formatting
 */

/**
 * Converts a snake_case or kebab-case string to PascalCase
 * @param text - The input string to convert
 * @returns The PascalCase version of the input
 * 
 * @example
 * toPascalCase('email_address') // 'EmailAddress'
 * toPascalCase('simple') // 'Simple' 
 * toPascalCase('kebab-case') // 'KebabCase'
 */
export function toPascalCase(text: string): string {
  // Replace hyphens with underscores, then split by underscores
  const s = text.replace(/[-_]+/g, '_');
  return s.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()).join('');
}

/**
 * Converts PascalCase or camelCase to snake_case
 * @param name - The input string to convert
 * @returns The snake_case version of the input
 * 
 * @example
 * toSnakeCase('EmailAddress') // 'email_address'
 * toSnakeCase('SimpleRegex') // 'simple_regex'
 */
export function toSnakeCase(name: string): string {
  const s1 = name.replace(/(.)([A-Z][a-z]+)/g, '$1_$2');
  return s1.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
}

/**
 * Capitalizes the first letter of a string
 * @param str - The input string
 * @returns The string with the first letter capitalized
 */
export function capitalize(str: string): string {
  if (str.length === 0) return str;
  return str.charAt(0).toUpperCase() + str.slice(1);
}