/**
 * Unit tests for range-query.dto helpers.
 */

import { BadRequestException } from '@nestjs/common';
import { validateRange, rangeToDate } from './range-query.dto';

describe('validateRange', () => {
  it('returns "30d" when range is undefined', () => {
    expect(validateRange(undefined)).toBe('30d');
  });

  it('returns "30d" when range is empty string', () => {
    expect(validateRange('')).toBe('30d');
  });

  it.each(['7d', '30d', '90d'] as const)(
    'accepts valid range "%s"',
    (range) => {
      expect(validateRange(range)).toBe(range);
    },
  );

  it('throws BadRequestException for invalid range', () => {
    expect(() => validateRange('5d')).toThrow(BadRequestException);
  });

  it('throws BadRequestException for "1y"', () => {
    expect(() => validateRange('1y')).toThrow(BadRequestException);
  });

  it('error message includes the invalid value', () => {
    try {
      validateRange('bogus');
      throw new Error('should have thrown');
    } catch (e) {
      expect((e as BadRequestException).message).toContain('bogus');
    }
  });
});

describe('rangeToDate', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    // Fix "now" to 2026-04-21T12:00:00Z
    jest.setSystemTime(new Date('2026-04-21T12:00:00Z'));
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('returns 7 days ago for "7d"', () => {
    const result = rangeToDate('7d');
    expect(result.toISOString()).toBe('2026-04-14T00:00:00.000Z');
  });

  it('returns 30 days ago for "30d"', () => {
    const result = rangeToDate('30d');
    expect(result.toISOString()).toBe('2026-03-22T00:00:00.000Z');
  });

  it('returns 90 days ago for "90d"', () => {
    const result = rangeToDate('90d');
    expect(result.toISOString()).toBe('2026-01-21T00:00:00.000Z');
  });

  it('returns start of UTC day (midnight)', () => {
    const result = rangeToDate('7d');
    expect(result.getUTCHours()).toBe(0);
    expect(result.getUTCMinutes()).toBe(0);
    expect(result.getUTCSeconds()).toBe(0);
    expect(result.getUTCMilliseconds()).toBe(0);
  });
});
