import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsInt,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

/**
 * A single entry in a plan-reorder payload.
 */
export class PlanPositionItem {
  @IsUUID('4')
  planId!: string;

  /** Zero-based display position within the series. */
  @IsInt()
  @Min(0)
  position!: number;
}

/**
 * DTO for PATCH /admin/series/:id/reorder-plans
 *
 * Accepts an array of { planId, position } pairs and bulk-updates
 * plans.position for all matching plans that belong to this series.
 *
 * Plans not included in the payload retain their current position.
 * Plans whose planId does not belong to this series are silently ignored.
 */
export class ReorderSeriesPlansDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => PlanPositionItem)
  plans!: PlanPositionItem[];
}
