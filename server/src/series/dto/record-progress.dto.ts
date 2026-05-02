import { IsInt, Min } from 'class-validator';

export class RecordProgressDto {
  /**
   * The 0-indexed position of the session that was just completed within
   * the series' ordered plan list. Used to bump currentSessionIndex.
   */
  @IsInt()
  @Min(0)
  sessionIndex!: number;
}
