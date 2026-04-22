/**
 * Range query parameter helpers for admin analytics endpoints.
 *
 * Valid ranges: '7d', '30d', '90d'. Default: '30d'.
 * Invalid values throw BadRequestException (HTTP 400).
 */

import { BadRequestException } from '@nestjs/common';
import type { AnalyticsRange } from '../../admin/dto/analytics.dto';

const VALID_RANGES: ReadonlySet<string> = new Set(['7d', '30d', '90d']);

const RANGE_DAYS: Record<AnalyticsRange, number> = {
  '7d': 7,
  '30d': 30,
  '90d': 90,
};

/**
 * Validate a range query parameter.
 *
 * @param range  Raw query string value (may be undefined)
 * @returns      Validated AnalyticsRange value (defaults to '30d')
 * @throws       BadRequestException if the value is present but invalid
 */
export function validateRange(range: string | undefined): AnalyticsRange {
  if (range === undefined || range === '') return '30d';

  if (!VALID_RANGES.has(range)) {
    throw new BadRequestException(
      `Invalid range "${range}". Valid values: 7d, 30d, 90d`,
    );
  }

  return range as AnalyticsRange;
}

/**
 * Convert a validated range string to a Date representing the start of the range.
 *
 * @param range  Validated range string ('7d' | '30d' | '90d')
 * @returns      Date that is `range` days ago from now (start of UTC day)
 */
export function rangeToDate(range: AnalyticsRange): Date {
  const days = RANGE_DAYS[range];
  const now = new Date();
  const start = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - days),
  );
  return start;
}
