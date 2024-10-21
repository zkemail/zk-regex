import { extractSubstrIdxes, extractSubstr } from '../pkg/zk_regex_apis';
import airbnbEml from './airbnb_eml';

describe('Extract substr test suite', async () => {
    test('Should extract indicies from object input', () => {
        const parts = {
            parts: [
                {
                    is_public: true,
                    regex_def: 'Hello'
                }
            ]
        };
        const result = extractSubstrIdxes(airbnbEml, parts, false);
        expect(result.length).toBe(1);
        expect(result[0].length).toBe(2);
    });

    test('Should extract indicies from object input, hide private', () => {
        const parts = {
            parts: [
                {
                    is_public: true,
                    regex_def: 'Hello '
                },
                {
                    is_public: false,
                    regex_def: 'guys!'
                }
            ]
        };
        const result = extractSubstrIdxes(airbnbEml, parts, false);
        expect(result.length).toBe(1);
        expect(result[0].length).toBe(2);
    });

    test('Should extract indicies from object input, reveal private', () => {
        const parts = {
            parts: [
                {
                    is_public: true,
                    regex_def: 'Hello '
                },
                {
                    is_public: false,
                    regex_def: 'guys!'
                }
            ]
        };
        const result = extractSubstrIdxes(airbnbEml, parts, true);
        expect(result.length).toBe(2);
        expect(result[0].length).toBe(2);
        expect(result[1].length).toBe(2);
    });

    test('Should extract indicies from stringified input', () => {
        const parts = {
            parts: [
                {
                    is_public: false,
                    regex_def: 'Hello'
                }
            ]
        };
        const result = extractSubstrIdxes(
            airbnbEml,
            JSON.stringify(parts),
            true
        );
        expect(result.length).toBe(1);
        expect(result[0].length).toBe(2);
    });

    test('Should throw helpful js error on wrong object input', () => {
        const parts = {
            wrong: 'input'
        };
        try {
            extractSubstrIdxes(airbnbEml, parts, false);
        } catch (err) {
            expect(err).toBe('Error: missing field `parts`');
            return;
        }
        throw new Error('Did not catch wrong input');
    });

    test('Should throw helpful js error on wrong stringified input', () => {
        const parts = {
            wrong: 'input'
        };
        try {
            extractSubstrIdxes(airbnbEml, JSON.stringify(parts), false);
        } catch (err) {
            const includesErr = err.includes(
                'Failed to parse JSON string: missing field `parts`'
            );
            expect(includesErr).toBe(true);
            return;
        }
        throw new Error('Did not catch wrong input');
    });

    test('Should throw helpful js error on wrong object input 2', () => {
        const parts = {
            parts: [
                {
                    is_public: false
                }
            ]
        };
        try {
            extractSubstrIdxes(airbnbEml, parts, false);
        } catch (err) {
            expect(err).toBe('Error: missing field `regex_def`');
            return;
        }
        throw new Error('Did not catch wrong input');
    });

    test('Should throw helpful js error on no found result', () => {
        const parts = {
            parts: [
                {
                    is_public: true,
                    regex_def: 'Hello'
                },
                {
                    is_public: false,
                    regex_def: 'yall!'
                }
            ]
        };
        try {
            extractSubstrIdxes(airbnbEml, parts, false);
        } catch (err) {
            const includes = err.includes(
                'Failed to extract indxes: Substring of the entire regex (Hello)(yall!) is not found given input_str'
            );
            expect(includes).toBe(true);
            return;
        }
        throw new Error('Did not throw an error');
    });

    test('extractSubstr should return actual matched string', () => {
        const parts = {
            parts: [
                {
                    is_public: true,
                    regex_def: 'Hello'
                }
            ]
        };
        const strs = extractSubstr(airbnbEml, parts, false);
        expect(strs[0]).toBe('Hello');
    });

    test('extractSubstr should return an empty array on all private fields', () => {
        const parts = {
            parts: [
                {
                    is_public: false,
                    regex_def: 'Hello'
                }
            ]
        };
        const strs = extractSubstr(airbnbEml, parts, false);
        expect(strs.length).toBe(0);
    });
});
