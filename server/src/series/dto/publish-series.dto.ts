import { IsBoolean } from 'class-validator';

/**
 * DTO for PATCH /admin/series/:id/publish
 *
 * Toggles the is_published flag on a series.
 * Setting is_published=true makes the series visible to subscribers.
 * Setting is_published=false immediately hides it from all users.
 */
export class PublishSeriesDto {
  @IsBoolean()
  isPublished!: boolean;
}
