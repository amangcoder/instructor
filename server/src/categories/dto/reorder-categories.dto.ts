import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsInt,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

/**
 * A single item in the reorder payload — maps a category ID to its new position.
 */
export class ReorderItemDto {
  /** UUID of the category to reposition. */
  @IsUUID()
  id!: string;

  /** New zero-based sort position. */
  @IsInt()
  @Min(0)
  sortOrder!: number;
}

/**
 * ReorderCategoriesDto — bulk-update the sort_order of multiple categories.
 *
 * At least one item must be supplied. The update is applied atomically so that
 * the Discover surface never sees a partially-reordered list.
 */
export class ReorderCategoriesDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ReorderItemDto)
  items!: ReorderItemDto[];
}
