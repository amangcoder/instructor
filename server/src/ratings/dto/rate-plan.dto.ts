import { IsInt, Max, Min } from 'class-validator';

export class RatePlanDto {
  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;
}
